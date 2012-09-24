class Accounts < Entities
  def setup_data
    @default_type = :SQLiteAC
		@data_field_id = :id
    
    value_str :name
    value_str :desc
    value_str :global_id
    value_str :total
    value_int :multiplier
    value_int :index
		value_entity_account :account_id
  end
    
	def self.create( name, desc, parent, global_id )
		a = super( :name => name, :desc => desc, :account_id => parent.id,
			:global_id => global_id.to_s )
		a.total = "0"
		# TODO: u_l.save?
		if parent
			a.multiplier = parent.multiplier
		else
			a.multiplier = 1
		end
		a.new_index
		a.save
		dputs 2, "Created account #{a.name}"
		a
	end

	# Gets an account from a string, if it doesn't exist yet, creates it.
	# It will update it anyway.
	def self.from_s( str )
		desc, str = str.split("\r")
		if not str
			dputs 0, "Invalid account found: #{desc}"
			return [ -1, nil ]
		end
		global_id, total, name, multiplier, par = str.split("\t")
		total, multiplier = total.to_f, multiplier.to_f
		dputs 3, "Here comes the account: " + global_id.to_s
		dputs 5, "par: #{par}"
		if par
			parent = Accounts.find_by_global_id( par )
			dputs 5, "parent: #{parent.global_id}"
		end
		dputs 3, "global_id: #{global_id}"
		# Does the account already exist?
		our_a = nil
		pid = par ? parent.id : 0
		if not ( our_a = Accounts.find_by_global_id(global_id) )
			# Create it
			our_a = Accounts.create( name, desc, Accounts.find_by_id( par ), global_id )
		end
		# And update it
		our_a.set_nochildmult( name, desc, pid, multiplier )
		our_a.global_id = global_id
		our_a.save
		dputs 2, "Saved account #{name} with index #{our_a.index} and global_id #{our_a.global_id}"
		return our_a
	end
end

class Account < Entity

	# This gets the tree under that account, breadth-first
	def get_tree
		yield self
		accounts.each{|a|
			a.get_tree{|b| yield b} 
		}
	end
    
	def get_tree_debug( ind = "" )
		yield self
		dputs 0, "get_tree_ #{ind}#{self.name}"
		accounts.each{|a|
			a.get_tree_debug( "#{ind} " ){|b| yield b} 
		}
	end
    
	def path( sep = "::", p="", first=true )
		if self.account
			return self.account.path( sep, p, false ) + self.name + ( first ? "" : sep )
		else
			return self.name + sep
		end
	end
    
	def new_index()
		u_l = Users.find_by_name('local')
		self.index = u_l.account_index
		u_l.account_index += 1
		u_l.save
		dputs 3, "Index for account #{name} is #{index}"
	end
    
	# Sets different new parameters.
	def set_nochildmult( name, desc, parent, multiplier = 1, users = [] )
		if self.new_record?
			dputs 4, "New record in nochildmult"
			self.total = 0
			# We need to save so that we have an id...
			save
			self.global_id = User.find_by_name('local').full + "-" + self.id.to_s
		end
		self.name, self.desc, self.account_id = name, desc, parent;
		# TODO: implement link between user-table and account-table
		# self.users = users ? users.join(":") : ""
		self.multiplier = multiplier
		# And recalculate everything.
		total = 0
		movements.each{|m|
			v = m.get_value( self )
			total += v
		}
		new_index
		save
	end
	def set( name, desc, parent, multiplier = 1, users = [] )
		set_nochildmult( name, desc, parent, multiplier, users )
		# All descendants shall have the same multiplier
		set_child_multipliers( multiplier )
		save
	end
    
	# Sort first regarding inverse date (newest first), then description, 
	# and finally the value
	def movements( from = nil, to = nil )
		dputs 5, "Account::movements"
		timer_start
		movs = ( movements_src + movements_dst )
		if ( from != nil and to != nil )
			movs.delete_if{ |m|
				( m.date < from or m.date > to )
			}
			dputs 3, "Rejected some elements"
		end
		timer_read("rejected elements")
		sorted = movs.sort{ |a,b|
			ret = 0
			if a.date and b.date
				ret = -( a.date <=> b.date )
			end
			if ret == 0
				if a.desc and b.desc
					ret = a.desc <=> b.desc
				end
				if ret == 0
					if a.value and b.value
						ret = a.value.to_f <=> b.value.to_f
					end
				end
			end
			ret
		}
		timer_read( "Sorting movements: " )
		sorted
	end
	    
	def to_s( add_path = false )
		if account || true
			"Account-desc: #{name.to_s}, #{global_id}"
			"#{desc}\r#{global_id}\t" + 
        "#{total.to_s}\t#{name.to_s}\t#{multiplier.to_s}\t" +
				( account_id ? account.global_id.to_s : "" ) +
				( add_path ? "\t#{path}" : "" )
		else
			"nope"
		end
	end
    
	def is_empty
		size = self.movements.select{|m| m.value.to_f != 0.0 }.size
		dputs 2, "Account #{self.name} has #{size} non-zero elements"
		if size == 0 and self.accounts.size == 0
			return true
		end
		return false
	end
    
	# Be sure that all descendants have the same multiplier
	def set_child_multipliers( m )
		dputs 3, "Setting multiplier from #{name} to #{m}"
		self.multiplier = m
		save
		return if not accounts
		accounts.each{ |acc|
			acc.set_child_multipliers( m )
		}
	end
	
	def accounts
		Accounts.match_by_account_id( self.id )
	end
	
	def account
		account_id
	end
	
	def movements_src
		Movements.match_by_account_src_id( self.id )
	end
	
	def movements_dst
		Movements.match_by_account_dst_id( self.id )
	end
end
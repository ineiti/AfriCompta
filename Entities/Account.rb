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
    
	def self.create( name, desc = "Too lazy", parent = nil, global_id = "" )
		if parent
		  if parent.class != Account
				parent = Accounts.match_by_index( parent ).first
			end
  		a = super( :name => name, :desc => desc, :account_id => parent.id,
	  		:global_id => global_id.to_s, :multiplier => parent.multiplier )
		else
  		a = super( :name => name, :desc => desc, :account_id => 0,
	  		:global_id => global_id.to_s, :multiplier => 1 )
		end
		a.total = "0"
		a.new_index
		if global_id == ""
			a.global_id = Users.find_by_name('local').full + "-" + a.id.to_s
		end
		a.save
		dputs 2, "Created account #{a.name}"
		a
	end
	
	def self.create_path( path, desc )
		elements = path.split( "::" )
		last_id = nil
		elements.each{|e|
			t = Accounts.match_by_name( e ).select{|a|
				dputs 5, "Account_id is #{a.account_id}"
				if a.account_id == last_id
					last_id = a
				end
			}
			if t == []
				last_id = Accounts.create( e, desc, last_id )
			end
		}
		last_id
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
	
	def self.get_by_path( p )
		self.search_all.to_a.each{|a|
			if a.global_id and a.path == p
				dputs 3, "Found #{a.inspect}, a.id is #{a.id}"
				return a
			end
		}
		return nil
	end

	def self.get_id_by_path( p )
		if a = get_by_path( p )
			return a.id.to_s
		else
			return nil
		end
	end
	
	def self.archive( month_start = 1, this_year = nil )
		
		def archive_parent( years_archived, year, acc )
			ddputs 3, "years_archived is #{years_archived.inspect}"
			if not years_archived.has_key? year
				dputs 2, "Adding #{year}"
				years_archived[year] = 
					Accounts.create_path( "Archive::#{year}", "New archive" )
			end
			# This means we're more than one level below root, so we can't
			# just copy easily
			if acc.path.split('::').count > 2
				return Accounts.create_path( "Archive::#{year}::"+
						"#{acc.parent.path.gsub(/^Root::/,'')}", "New archive" )
			else
				return years_archived[year]
			end
		end
		
		if not this_year
			this_year = Time.now.year
			Time.now.month < month_start and this_year -= 1
		end
		
		root = self.find_by_name( 'Root' )
		if root.account_id
			dputs 0, "Can't archive with Root is not in root: #{root.account_id.inspect}!"
		end
		
		archive = self.find_by_name( 'Archive' )
		if not archive
			archive = self.create( 'Archive' )
		end
		
		years_archived = {}
		archive.accounts.each{|a| years_archived[a.name] = a }
		
		dputs 2, "Got root and archive"
		# For every account we search the most-used year, so
		# that we can move the account to that archive. This way
		# we omit as many as possible updates for the clients, as
		# every displacement of a movement will have to be updated,
		# while the displacement of an account is much simpler
		root.get_tree{|acc|
			ddputs 3, "Looking at account #{acc.path}"
			years = Hash.new(0)
			acc.movements.each{|mov|
				y, m, d = mov.date.split("-").collect{|d| d.to_i}
				ddputs 5, "Date of #{mov.desc} is #{mov.date}"
				m < month_start and y -= 1
				years[y] += 1
			}
			ddputs 3, "years is #{years.inspect}"
			
			if years.size > 0
				most_used = years.index( years.values.max )
				last_used = years.keys.max
				acc_path = acc.path
				
				ddputs 3, "most_used: #{most_used} - last_used: #{last_used}" +
					"- acc_path: #{acc_path}"
				
				# First move all other movements around
				years.delete( most_used )
				if years.keys.size > 0
					years.keys.each{|y|
						ddputs 3, "Creating account #{acc.name} for year #{y}"
						years[y] = Accounts.create( acc.name, acc.desc, 
							archive_parent( years_archived, y, acc ))
						ddputs 3, "years[y] is #{years[y].path}"
					}
					acc.movements.each{|mov|
						y, m, d = mov.date.split("-").collect{|d| d.to_i}
						ddputs 5, "Date of #{mov.desc} is #{mov.date}"
						m < month_start and y -= 1
						if years.has_key? y
							ddputs 5, "Moving to #{years[y].inspect}: " +
								"#{mov.account_src.id} - #{mov.account_dst.id} - #{acc.id}"
							if mov.account_src.id == acc.id
								ddputs 5, "Moving src"
								mov.account_src_id = years[y]
							else
								ddputs 5, "Moving dst"
								mov.account_dst_id = years[y]
							end
							mov.new_index
						end
					}
					ddputs 5, "Movements left in account #{acc.path}:"
					acc.movements.each{|m|
						ddputs 5, m.desc
					}
				end

				if most_used != this_year
					# Now move account to archive-year of most movements
					ddputs 3, "Most used year is #{most_used}"
					parent = archive_parent( years_archived, most_used, acc )
					ddputs 3, "Moving account #{acc.path} to #{parent.path}"
					acc.account_id = parent
					acc.new_index
				end

				# Check whether we need to add the account to the current year
				if last_used == this_year - 1
					ddputs 3, "Adding #{acc_path} to this year"
					Accounts.create_path( acc_path, "Copied from archive" )
				end
			else
				ddputs 3, "Empty account"
			end
		}
		ddputs 3, "Root-tree is now"
		root.get_tree{|a|
			ddputs 3, a.path
		}
		ddputs 3, "Archive-tree is now"
		archive.get_tree{|a|
			ddputs 3, a.path
		}
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
			return self.account.path( sep, p, false ) + sep + self.name
		else
			return self.name
		end
	end
	
	def get_path( sep = "::", p = "", first = true )
		path( sep, p, first )
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
	
	# This is the parent account
	def account
		account_id
	end
	
	def parent
		account
	end
	
	def movements_src
		Movements.match_by_account_src_id( self.id )
	end
	
	def movements_dst
		Movements.match_by_account_dst_id( self.id )
	end
end
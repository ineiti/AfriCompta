class Movements < Entities
  def setup_data
		dputs 0, "init_movements"
    @default_type = :SQLiteAC
		@data_field_id = :id

    value_entity_account :account_src_id
    value_entity_account :account_dst_id
    value_float :value
    value_str :desc
    value_date :date
    value_int :revision
    value_str :global_id
    value_int :index
  end

	def self.from_json( str )
		self.from_s( ActiveSupport::JSON.decode( str )["str"] )
	end
    
	def self.from_s( str )
		desc, str = str.split("\r")
		global_id, value, date, src, dst = str.split("\t")
		date = Time.parse(date).to_ss
		value = value.to_f
		a_src = Accounts.find_by_global_id( src )
		a_dst = Accounts.find_by_global_id( dst )
		if not a_src or not a_dst
			dputs 0, "error: didn't find " + src.to_s + " or " + dst.to_s
			return [ -1, nil ]
		end
		# Does the movement already exist?
		our_m = nil
		if not ( our_m = self.find_by_global_id(global_id) )
			dputs 3, "New movement"
			our_m = self.create( desc, date, value, 
				a_src.id, a_dst.id )
			our_m.global_id = global_id
		else
			dputs 2, "Overwriting movement #{global_id}"
			# And update it
			our_m.set( desc, date, value, a_src.id, a_dst.id )
		end
		our_m.save
		return our_m
	end

	def self.create( desc, date, value, source, dest )
		return nil if source == dest
		t = super( :desc => desc, :date => date, :value => 0, 
			:account_src_id => source, :account_dst_id => dest )
		t.save
		t.value = value
		t.global_id = Users.find_by_name("local").full + "-" + t.id.to_s
		t
	end
end



class Movement < Entity
	def new_index()
		u_l = Users.find_by_name('local')
		self.index = u_l.movement_index
		u_l.movement_index += 1
		u_l.save
		dputs 3, "index is #{self.index} and date is --#{self.date}--"
		dputs 3, "User('local').index is: " + Users.find_by_name('local').movement_index.to_s
	end
    
	def get_index()
		return self.index
	end
    
	def is_in_account(a)
		return ( a == account_src or a == account_dst )
	end
    
	def value=(v)
		if account_src and account_dst
			dputs 3, "value=" + v.to_s + ":" + account_src.total.to_s
			diff = value.to_f - v
			account_src.total = account_src.total.to_f + ( diff * account_src.multiplier )
			account_dst.total = account_dst.total.to_f - ( diff * account_dst.multiplier )
			account_src.save
			account_dst.save
		end
		super( v )
	end
    
	def get_value( account )
		value.to_f * account.multiplier.to_f * ( account_src == account ? -1 : 1 )
	end
    
	def get_other_account( account )
		account_src == account ? account_dst : account_src
	end
    
	def set( desc, date, value, source, dest )
		dputs 3, "self.value " + self.value.to_s + " - " + value.to_s
		self.value = 0
		self.account_src_id, self.account_dst_id = source, dest
		if false
			# Do some date-magic, so that we can give either the day, day and month or
			# a complete date. The rest is filled up with todays date.
			date = date.split("/")
			da = Date.today
			d = [ da.day, da.month, da.year ]
			date += d.last( 3 - date.size )
			if date[2].to_s.size > 2
				self.date = Date.strptime( date.join("/"), "%d/%m/%Y" )
			else
				self.date = Date.strptime( date.join("/"), "%d/%m/%y" )
			end
		else
			self.date = Date.from_s(date)
		end
		self.desc, self.value = desc, value
		dputs 4, "Going to save"
		self.new_index()
		save
		dputs 4, "Date " + self.date.to_s
	end
    
	def to_s
		dputs 5, "I am: #{to_hash.inspect} - my id is: #{global_id}"
		"#{desc}\r#{global_id}\t" + 
      "#{value.to_s}\t#{date.to_s}\t" +
      account_src.global_id.to_s + "\t" +
      account_dst.global_id.to_s
	end
	
	def to_json
		ActiveSupport::JSON.encode( :str => to_s )
	end

	# Copying over data from old AfriCompta
	def account_src
		account_src_id
	end
	
	def account_dst
		account_dst_id
	end
end
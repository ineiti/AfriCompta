class Users < Entities

  def setup_data
    @default_type = :SQLiteAC
		@data_field_id = :id
    
    value_str :name
    value_str :full
    value_str :pass
		#value_array :accounts
		# The last account_index that got transmitted
    value_int :account_index
		# The last movement_index that got transmitted
    value_int :movement_index
  end
	
	def create( name, full, pass )
		new_user = super( :name => name, :full => full, :pass => pass )
		new_user.account_index = new_user.movement_index = 0
		new_user
	end
end

class User < Entity
	def update_movement_index
		self.movement_index = Users.find_by_name('local').movement_index - 1
		save
	end
    
	def update_account_index
		self.account_index = Users.find_by_name('local').account_index - 1
		save
	end
end
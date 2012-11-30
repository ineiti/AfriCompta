class Remotes < Entities
	
	def create( d )
		r = super( d )
		d.has_key?( :account_index ) || r.account_index = 0
		d.has_key?( :movement_index ) || r.movement_index = 0
		r
	end
	
  def setup_data
		value_str :url
		value_str :name
		value_str :pass
		value_int :account_index
		value_int :movement_index
  end
end

class Remote < Entity
	def update_movement_index
		self.movement_index = Users.find_by_name('local').movement_index - 1
		self.save
	end

	def update_account_index
		self.account_index = Users.find_by_name('local').account_index - 1
		self.save
	end
end

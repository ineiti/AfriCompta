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

  def init
    user = Users.create('local', Digest::MD5.hexdigest((rand 2**128).to_s).to_s,
                        rand(2 ** 128).to_s)
    dputs(1) { "Created local user #{user}" }
  end

  def load
    super
    if Users.search_by_name('local').count == 0
      dputs(0) { 'User init not here' }
      init
    end
  end

  def migration_1(u)
    u.account_index ||= 0
    u.movement_index ||= 0
  end

  def create(name, full = nil, pass = nil)
    if not full or not pass
      dputs(2) { "Creating with hash: #{name.inspect}" }
      name, full, pass = name[:name], name[:full], name[:pass]
    end
    new_user = super(:name => name, :full => full, :pass => pass)
    new_user.account_index, new_user.movement_index = 0, 0
    new_user
  end
end

class User < Entity
  def update_movement_index
    self.movement_index = Users.match_by_name('local').movement_index - 1
  end

  def update_account_index
    self.account_index = Users.match_by_name('local').account_index - 1
  end

  def update_all
    update_movement_index
    update_account_index
  end
end

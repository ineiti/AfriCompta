class Remotes < Entities

  def create(d)
    r = super(d)
    d.has_key?(:account_index) || r.account_index = 0
    d.has_key?(:movement_index) || r.movement_index = 0
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
    self.movement_index = Users.match_by_name('local').movement_index - 1
  end

  def update_account_index
    self.account_index = Users.match_by_name('local').account_index - 1
  end

  def post_form(path, hash)
    dputs(4) { "Starting postForm with path #{path}" }
    Net::HTTP.post_form(URI.parse(url + "/merge/#{path}"),
                        {'user' => name, 'pass' => pass}.merge(hash))
    dputs(4) { "Ending postForm with path #{path}" }
  end

  def get_form(path)
    url_parsed = URI.parse(url)
    dputs(4) { "Starting getForm with path #{path} - #{url_parsed.inspect}" }
    dputs(4) { "Finished parsing #{@remote.url}" }
    ret = Net::HTTP.get(url_parsed.host, "#{url_parsed.path}/merge/#{path}/#{name},#{pass}", url_parsed.port)
    dputs(4) { "Ending getForm with path #{path}" }
    ret
  end

  # Calls the remote end and searches for new accounts and movements
  # on both sides. Steps:
  # 0: check version
  # 1: get remote accounts
  # 2: send our accounts
  # 3: get remote movements
  # 4: send our movements
  # 5: update the indexes
  # The variable +step+ can be used to watch the progress if it is called
  # in a thread
  def do_merge(remote_id)
    @step = 'preparation'
    @account_index_stop, @movement_index_stop,
        @got_accounts, @put_accounts,
        @got_movements, @put_movements, @put_movements_changes =
        [0] * 7

    @remote = Remotes.find_by_id(remote_id)
    u = Users.find_by_name('local')
    log_msg :Merging, "Starting to merge for #{@remote}"

    @step = 'checking remote'
    check_version

    @step = 'getting remote accounts'
    get_remote_accounts

    @step = 'sending our accounts'
    send_accounts

    @step = 'getting remote movements'
    get_remote_movements(u)

    @step = 'sending movements'
    send_movements

    @step = 'updating all indexes'
    # Update the pointer
    @remote.update_movement_index
    # Update the remote pointers
    get_form('reset_user_indexes')

    @step = 'done'
  end

  def check_version
    local_id = Users.find_by_name('local').full
    dputs(2) { "Local id is: #{local_id}" }
    if (local_id == get_form('local_id'))
      dputs(0) { 'Both locals have same ID' }
      raise 'Same ID for local'
    end

    # Check the versions
    if (vers = get_form('version')) != $VERSION.to_s
      if (vers =~ /not known/)
        dputs(0) { 'Username / password not recognized' }
        raise 'Wrong credentials'
      else
        dputs(0) { "Got version #{vers} instead of #{$VERSION.to_s}" }
        raise 'Wrong version'
      end
    end
  end

  def get_remote_accounts
    dputs(2) { 'Getting remotes' }
    @account_index_stop = u.account_index - 1
    accounts = get_form('accounts_get')
    accounts.split("\n").each { |a|
      acc = Accounts.from_s(a)
      dputs(2) { "Got account #{acc.name}" }
      @got_accounts += 1
    }
  end

  def send_movements
    @movement_index_start = @remote.movement_index + 1
    @movement_count = 0
    if @movement_index_start <= @movement_index_stop
      dputs(1) { "Movements to send: #{@movement_index_start}.." +
          "#{@movement_index_stop}" }
      movements = []
      Movements.data.select { |k, v| v._rev_index.between(
          @movement_index_start, @movement_index_stop
      ) }.each { |k, v|
      }
      Movements.find(:all, :conditions =>
                             {:rev_index => @movement_index_start..@movement_index_stop}).each { |m|
        movements.push(m.to_json)
        @put_movements += 1
      }
      @movement_count = movements.size
      dputs(1) { "Having #{movements.size} movements to send" }
      while movements.size > 0
        # We'll do it by bunches of 10
        movements_put = movements.shift 10
        dputs(1) { 'Putting one bunch of 10 movements' }
        dputs(4) { movements_put.to_json }
        post_form('movements_put', {'movements' => movements_put.to_json})
        @put_movements_changes += 1
        # TODO: remove
        # movements = []
      end
    else
      dputs(1) { 'No movements to send' }
    end
  end

  def get_remote_movements(u)
    dputs(1) { 'Getting movements' }
    # Now merge the movements
    movements = get_form('movements_get')
    @movement_index_stop = u.movement_index - 1
    movements.split("\n").each { |m|
      dputs(2) { "String is: \n#{m}" }
      mov = Movements.from_s(m)
      @got_movements += 1
    }
  end

  def send_accounts
    @account_index_start = @remote.account_index + 1
    if @account_index_start <= @account_index_stop
      dputs(1) { "Accounts to send: #{@account_index_start}..#{@account_index_stop}" }
      # We have to start at the bottom, else we can get into trouble with regard
      # to children not having their parents yet...
      Accounts.find_all_by_account_id(0).to_a.concat(
          Accounts.find_all_by_account_id(nil)).each { |a|
        dputs(2) { "Root is #{a.inspect}" }
        a.get_tree { |acc|
          debug(3, "Index of #{acc.name} is #{acc.get_index}")
          if (@account_index_start..@account_index_stop) === acc.rev_index
            dputs(2) { "Account with index #{acc.rev_index} is being transferred" }
            post_form('account_put', {'account' => acc.to_s})
            @put_accounts += 1
          end
        }
      }
    else
      dputs(1) { 'No accounts to send' }
    end
    # Update the pointer
    @remote.update_account_index
  end

  # Is used to reset the pointers, supposes both databases are equal -
  # Should probably be used with care
  def do_copied
    check_version

    # Update local indexes
    u = Users.find_by_name('local')
    update_account_index
    update_movement_index

    # Update remote indexes
    get_form('reset_user_indexes')

    # Check if everything is OK
    acc, mov = get_form('index').split(',')

    if acc.to_i != u.account_index
      dputs(0) { "Trying to do 'copied' with wrong account-indexes" }
      dputs(0) { "#{acc.to_i} - #{u.account_index}" }
    end
    if mov.to_i != u.movement_index
      dputs(0) { "Trying to do 'copied' with wrong movement-indexes" }
      dputs(0) { "#{mov.to_i} - #{u.movement_index}" }
    end
    return true
  end

end

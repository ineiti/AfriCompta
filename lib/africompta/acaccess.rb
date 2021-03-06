# This is the interface to AfriCompta. It is called through different
# Post/Get-handlers over HTTP


$VERSION = 0x1120

class ACaccess < RPCQooxdooPath
  def self.parse(r, p, q)
    dputs(2) { "in ACaccess: #{p} - #{q.inspect}" }
    method = p.gsub(/^\/acaccess\/merge\//, '')
    dputs(3) { "Calling method #{method} of #{r}" }
    case r
      when /GET/
        ret = self.get(method)
      when /POST/
        ret = self.post(method, q)
    end
    dputs(3) { "Result is #{ret.inspect}" }
    ret
  end

  def self.print_movements(start, stop)
    start, stop = start.to_i, stop.to_i
    dputs(2) { "Doing print_movements from #{start.class}:#{start}"+
        " to #{stop.class}:#{stop}" }
    ret = ''
#    Movements.search_all.select{|m|
#      mi = m.rev_index
#      m and mi and mi >= start and mi <= stop
    Movements.search_index_range(start, stop).each { |m|
      if start > 0
        dputs(4) { "Mer: Movement #{m.desc}, #{m.value}" }
      end
      ret += m.to_s + "\n"
    }
    dputs(3) { "Found movements: #{ret.inspect}" }
    ret
  end

  def self.print_movements_actual(start, stop)
    start, stop = start.to_i, stop.to_i
    dputs(2) { "Doing print_movements_actual from #{start.class}:#{start}"+
        " to #{stop.class}:#{stop}" }
    ret = ''
    actual_ids = []
    AccountRoot.actual.get_tree { |a|
      actual_ids.push a.id
    }
    movs = Movements.search_all.select { |m|
      mi = m.rev_index
      m and mi and mi >= start and mi <= stop and actual_ids.find(m.account_src_id)
    }
    dputs(2) { "Found #{movs.length} movements between #{start}..#{stop}" }
    movs.each { |m|
      if start > 0
        dputs(4) { "Mer: Movement #{m.desc}, #{m.value}" }
        ai = actual_ids.find(m.account_src_id.id)
        dputs(4) { "movement_src is #{m.account_src_id.inspect} from #{ai.inspect}" }
        dputs(4) { "actual_ids is #{actual_ids.inspect}" }
      end
      ret += m.to_s + "\n"
    }
    dputs(3) { "Found movements: #{ret.inspect}" }
    ret
  end

  def self.accounts_fetch(user)
    Accounts.data.select { |_k, v| v._rev_index > user.account_index }.
        collect { |k, _v| Accounts.get_data_instance(k) }.
        sort_by { |a| a.path }.
        collect { |a| a.to_s }.
        join("\n")
  end

  def self.get(p)
    # Two cases:
    # path/arg/user,pass - arg is used
    # path/user,pass - arg is nil
    path, arg, id = p.split('/')
    arg, id = id, arg if not id
    user, pass = id.split(',')

    log_msg 'ACaccess.get', "get-merge-path #{path} - #{arg} with " +
                              "user #{user} and pass #{pass}"
    u = Users.match_by_name(user)
    u_local = Users.match_by_name('local')
    if not (u and u.pass == pass)
      return "User #{user} not known with pass #{pass}"
    end

    case path
      when /accounts_get(.*)/
        # Gets all accounts available (to that user) that have been changed
        # since the last update, again, do it from the root(s), else we have
        # a problem for children without parents
        ret = ''
        dputs(2) { "user index is: #{u.account_index}" }
        # Returns only one account
        case $1
          when '_one'
            return Accounts.match_by_global_id(arg).to_s
          when '_all'
            dputs(2) { 'Putting all accounts' }
            ret = Accounts.search_all.collect { |acc|
              dputs(4) { "Found account #{acc.name} with index #{acc.rev_index}" }
              acc.to_s(true)
            }.join("\n")
          when '_count'
            ret += Accounts.search_all.size.to_s
          when '_part'
            acc_start, acc_end = arg.split(',')
            dputs(2) { "Putting accounts #{acc_start}..#{acc_end}" }
            Accounts.search_all.select { |acc|
              acc.rev_index >= acc_start.to_i and acc.rev_index <= acc_end.to_i
            }.each { |acc|
              dputs(4) { "Found account #{acc.name} with index #{acc.rev_index}" }
              ret += "#{acc.to_s(true)}\n"
            }
          else
            dputs(2) { 'Starting to search accounts' }
            t = Time.now
            ret += ACaccess.accounts_fetch(u)
            dputs(2) { "Found #{ret.count("\n")} after #{Time.now - t} seconds" }
        end
        dputs(3) { 'Finished search' }
        return ret
      # Gets all movements (for the accounts of that user)
      when /movements_get(.*)/
        dputs(2) { "movements_get#{$1} with #{arg.inspect}" }
        start, stop = u.movement_index + 1, u_local.movement_index - 1
        ret = case $1
                when '_one'
                  # Returns only one account
                  Movements.match_by_global_id(arg).to_s
                when '_all_actual'
                  start, stop = arg.split(/,/)
                  print_movements_actual(start, stop)
                when '_all'
                  Movements.search_all.collect { |m|
                    m.to_s
                  }.join("\n")
                when '_range'
                  start, stop = arg.split(/,/)
                  print_movements(start, stop)
                else
                  print_movements(start, stop)
              end
        dputs(2) { "Sending a total of #{ret.length}" }
        dputs(3) { "Sending:\n #{ret.inspect}" }
        return ret

      when 'version'
        return $VERSION.to_s

      when 'index'
        return [u_local.account_index, u_local.movement_index].join(',')

      when 'local_id'
        return u_local.full

      when 'reset_user_indexes'
        u.update_account_index
        u.update_movement_index

      when 'reset_user_account_indexes'
        u.update_account_index

      when 'reset_user_movement_indexes'
        u.update_movement_index

      when 'movement_delete'
        dputs(3) { "Going to delete movement #{arg}" }
        while mov = Movements.match_by_global_id(arg)
          dputs(3) { "Found movement #{mov.inspect}" }
          mov.delete
        end
        dputs(3) { 'Finished deleting' }

      when 'get_db'
        Entities.save_all
        return IO.read(Accounts.storage[:SQLiteAC].db_file)
    end

    return ''
  end

  def self.post(path, input)
    #dputs_func
    dputs(5) { "self.post with #{path} and #{input.inspect}" }
    log_msg 'ACaccess.post', "post-merge-path #{path} with " +
                               "user #{input['user']} and pass #{input['pass']}"
    user, pass = input['user'], input['pass']
    u = Users.match_by_name(user)
    if not (u and u.pass == pass)
      dputs(1) { "Didn't find user #{user}" }
      return "User #{user} not known with pass #{pass}"
    end
    case path
      # Retrieves id of the path of the account
      when /account_get_id/
        account = input['account']
        dputs(2) { "account_get_id with path #{account}" }
        a = Accounts.get_id_by_path(account)
        a and return a
        dputs(2) { "didn't find anything" }
        return nil

      when 'movements_put'
        dputs(3) { "Going to put some movements: #{input['movements'].inspect}" }
        movs = ActiveSupport::JSON.decode(input['movements'])
        dputs(3) { "movs is now #{movs.inspect}" }
        if movs.size > 0
          movs.each { |m|
            if mov = Movements.from_json(m)
              dputs(2) { "Saved movement #{mov.global_id}" }
            else
              dputs(0) { "Error: couldn't create movement from #{m.inspect}" }
            end
            u.update_movement_index unless input._debug
          }
        end
      when 'movement_delete'
        dputs(3) { 'Going to delete movement' }
        while mov = Movements.match_by_global_id(input['global_id'])
          dputs(3) { "Found movement #{mov.inspect}" }
          mov.delete
        end
        dputs(3) { 'Finished deleting' }
      when 'account_put'
        dputs(3) { "Going to put account #{input['account'].inspect}" }
        acc = Accounts.from_s(input['account'])
        u.update_account_index unless input._debug
        dputs(2) { "Saved account #{acc.global_id}" }
      when 'account_delete'
        dputs(3) { 'Going to delete account' }
        acc = Accounts.match_by_global_id(input['global_id'])
        acc.delete(true)
    end
    return 'ok'
  end

end


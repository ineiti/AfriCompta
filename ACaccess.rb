# This is the interface to AfriCompta. It is called through different
# Post/Get-handlers over HTTP


$VERSION = 0x1011

class ACaccess < RPCQooxdooPath
  def self.parse( r, p, q )
    dputs( 0 ){ "in ACaccess: #{p} - #{q.inspect}" }
    method = p.gsub( /^\/acaccess\/merge\//, '' )
    dputs( 3 ){ "Calling method #{method} of #{r}" }
    case r
    when /GET/
      ret = self.get( method )
    when /POST/
      ret = self.post( method, q )
    end
    dputs( 3 ){ "Result is #{ret.inspect}" }
    ret
  end

  def self.print_movements( accounts, start, stop )
    start, stop = start.to_i, stop.to_i
    dputs( 2 ){ "Doing print_movements from #{start.class}:#{start}"+ 
        " to #{stop.class}:#{stop}" }
    ret = ""
    Movements.search_all.select{|m|
      mi = m.index
      m and mi and mi >= start and mi <= stop 
    }.each{ |m|
      if start > 0
        dputs( 4 ){ "Mer: Movement #{m.desc}, #{m.value}" }
      end
      ret += m.to_s + "\n"
    }
    dputs( 3 ){ "Found movements: #{ret}" }
    ret
  end
    
  def self.get( p )
    # Two cases:
    # path/arg/user,pass - arg is used
    # path/user,pass - arg is nil
    path, arg, id = p.split("/")
    arg, id = id, arg if not id
    user, pass = id.split(",")
      
    dputs( 1 ){ "get-merge-path #{path} - #{arg} with user #{user} and pass #{pass}" }
    u = Users.match_by_name( user )
    u_local = Users.match_by_name('local')
    if not ( u and u.pass == pass )
      return "User " + user + " not known with pass " +
        pass
    end

    case path        
    when /accounts_get(.*)/
      # Gets all accounts available (to that user) that have been changed
      # since the last update, again, do it from the root(s), else we have
      # a problem for children without parents
      ret = ""
      dputs( 2 ){ "user index is: #{u.account_index}" }
      # Returns only one account
      if $1 == "_one"
        return Accounts.match_by_global_id( arg ).to_s
      end
      if $1 == "_all"
        dputs( 2 ){ "Putting all accounts" }
        Accounts.search_all.each{|acc|
          ddputs( 4 ){ "Found account #{acc.name} with index #{acc.index}" }
          ret += "#{acc.to_s( true )}\n"
        }
      else
        dputs( 2 ){ "Starting to search accounts" }
        Accounts.matches_by_account_id(0).to_a.sort{|a,b|
          a.global_id <=> b.global_id }.each{|a|
          dputs( 2 ){ "Found one root-account #{a.index} - #{a.path_id}" }
          if a.global_id
            dputs( 2 ){ "It's global" }
            a.get_tree{|acc|
              dputs( 4 ){ "In get_tree #{acc.index} - #{acc.path_id}" }
              if acc.index > u.account_index
                dputs( 4 ){ "Found account #{acc.name} with index #{acc.index}" }
                ret += "#{acc.to_s}\n"
              end
            }
          else
            dputs( 2 ){ "It's not global" }
          end
          dputs( 2 ){ "Will search for next" }
        }
      end
      dputs( 2 ){ "Finished search" }
      return ret
        
      # Gets all movements (for the accounts of that user)
    when /movements_get(.*)/
      dputs( 2 ){ "movements_get#{$1}" }
      start, stop = u.movement_index + 1, u_local.movement_index - 1
      # Returns only one account
      if $1 == "_one"
        return Movements.match_by_global_id( arg ).to_s
      end
      if $1 == "_all"
        start, stop = arg.split(/,/)
      end
      ret = print_movements( Accounts.search_all, start, stop )
      dputs( 3 ){ "Sending:\n #{ret}" }
      return ret
        
    when "version"
      return $VERSION.to_s
        
    when "index"
      return [ u_local.account_index, u_local.movement_index ].join(",")
      
    when "local_id"
      return u_local.full
                
    when "reset_user_indexes"
      u.update_account_index
      u.update_movement_index
    end
    return ""
  end
    
  def self.post( path, input )
    dputs( 5 ){ "self.post with #{path} and #{input.inspect}" }
    dputs( 1 ){ "post-merge-path #{path} with user #{input['user']} " +
        "and pass #{input['pass']}" }
    user, pass = input['user'], input['pass']
    u = Users.match_by_name( user )
    if not ( u and u.pass == pass )
      dputs( 0 ){ "Didn't find user #{user}" }
      return "User " + user + " not known with pass " +
        pass
    end
    case path
      # Retrieves id of the path of the account
    when /account_get_id/
      account = input['account']
      dputs( 2 ){ "account_get_id with path #{account}" }
      a = Accounts.get_id_by_path( account )
      a and return a
      dputs( 2 ){ "didn't find anything" }
      return nil

    when "movements_put"
      dputs( 3 ){ "Going to put some movements: #{input['movements'].inspect}" }
      movs = ActiveSupport::JSON.decode( input['movements'] )
      dputs( 3 ){ "movs is now #{movs.inspect}" }
      if movs.size > 0
        movs.each{ |m|
          mov = Movements.from_json( m )
          dputs( 2 ){ "Saved movement #{mov.global_id}" }
          u.update_movement_index
        }
      end
    when "movement_delete"
      dputs( 3 ){ "Going to delete movement" }
      mov = Movements.match_by_global_id( input['global_id'] )
      dputs(3){"Found movement #{mov.inspect}" }
      mov and mov.delete
      dputs(3){"Finished deleting"}
    when "account_put"
      dputs( 3 ){ "Going to put account" }
      acc = Accounts.from_s( input['account'] )
      u.update_account_index
      dputs( 2 ){ "Saved account #{acc.global_id}" }
    when "account_delete"
      dputs( 3 ){ "Going to delete account" }
      Accounts.match_by_global_id( input['global_id'] ).delete( true )
    end
    return "ok"
  end
end


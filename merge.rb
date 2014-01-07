# Does this change something?
require 'yaml'

module Compta::Controllers
  #
  # MERGE-related stuff
  #
  class MergeClasses < R '/merge/(.*)'
    def printMovements( start, stop )
      start, stop = start.to_i, stop.to_i
      debug 2, "Doing printMovements from #{start.class} to #{stop.class}"
      ret = ""
      Movement.find(:all, :conditions =>
          {:index => start..stop } ).each{ |m|
        if start > 0
          debug 4, "Mer: Movement #{m.desc}, #{m.value}"
        end
        ret += m.to_s + "\n"
      }
      return ret
    end

    def get(p)
      # Two cases:
      # path/arg/user,pass - arg is used
      # path/user,pass - arg is nil
      path, arg, id = p.split("/")
      arg, id = id, arg if not id
      user, pass = id.split(",")
      
      debug 1, "get-merge-path #{path} - #{arg} with user #{user} and pass #{pass}"
      u = User.find_by_name( user )
      u_local = User.find_by_name('local')
      if not ( u and u.pass == pass )
        return "User " + user + " not known with pass " +
          pass
      end
      case path
        
        # Gets all accounts available (to that user) that have been changed
        # since the last update, again, do it from the root(s), else we have
        # a problem for children without parents
      when /accounts_get(.*)/
        ret = ""
        debug 2, "user index is: #{u.account_index}"
        # Returns only one account
        if $1 == "_one"
          return Account.find_by_global_id( arg )
        end
        get_all = $1 == "_all"
        Account.find_all_by_account_id(0).to_a.each{|a|
          if a.global_id
            a.get_tree{|acc|
              if acc.rev_index > u.account_index or get_all
                debug 2, "Found account #{acc.name} with index #{acc.rev_index}"
                ret += "#{acc.to_s( get_all )}\n"
              end
            }
          end
        }
        return ret
        
        # Gets all movements (for the accounts of that user)
      when /movements_get(.*)/
        debug 2, "movements_get#{$1}"
        start, stop = u.movement_index + 1, u_local.movement_index - 1
        # Returns only one account
        if $1 == "_one"
          return Movement.find_by_global_id( arg )
        end
        if $1 == "_all"
          start, stop = arg.split(/,/)
          ret = printMovements( start, stop )
        end
        debug 3, "Sending:\n #{ret}"
        return ret
        
      when "version"
        return $VERSION.to_s
        
      when "index"
        return [ u_local.account_index, u_local.movement_index ].join(",")
        
      when "users_get"
        return User.find(:all).join("/")
        
      when "reset_user_indexes"
        u.update_account_index
        u.update_movement_index
        return ""
      end
    end
    
    def post(path)
      debug 1, "post-merge-path #{path} with user #{input.user} and pass #{input.pass}"
      u = User.find_by_name( input.user )
      if not (  u and u.pass == input.pass )
        debug 0, "Didn't find user #{user}"
        return "User " + user + " not known with pass " +
          pass
      end
      case path
        # Retrieves id of the path of the account
      when /account_get_id/
        debug 2, "account_get_id with path #{input.account}"
        Account.find(:all).to_a.each{|a|
          if a.global_id and a.path =~ /#{input.account}/
            debug 2, "Found #{a.inspect}, a.id is #{a.id}"
            return a.id.to_s
          end
        }
        debug 2, "didn't find anything"
        return nil

      when "movements_put"
        debug 3, "Going to put some movements"
        movs = ActiveSupport::JSON.decode( input.movements )
        if movs.size > 0
          movs.each{ |m|
            mov = Movement.from_json( m )
            debug 2, "Saved movement #{mov.global_id}"
            u.update_movement_index
          }
        end
      when "movement_delete"
        debug 3, "Going to delete movement"
        Movement.find_by_global_id( input.global_id ).delete
      when "account_put"
        debug 3, "Going to put account"
        acc = Account.from_s( input.account )
        u.update_account_index
        debug 2, "Saved account #{acc.global_id}"
      when "account_delete"
        debug 3, "Going to delete account"
        Account.find_by_global_id( input.global_id ).delete
      end
    end
  end
end

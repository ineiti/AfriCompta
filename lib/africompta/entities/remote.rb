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
    self.movement_index = Users.match_by_name('local').movement_index - 1
  end

  def update_account_index
    self.account_index = Users.match_by_name('local').account_index - 1
  end

  def postForm( path, hash )
    debug 5, "Starting postForm with path #{path}"
    Net::HTTP.post_form( URI.parse( @remote.url + "/merge/#{path}" ),
                         { 'user' => @remote.name, 'pass' => @remote.pass }.merge( hash ) )
    debug 5, "Ending postForm with path #{path}"
  end

  def getForm( path )
    url = URI.parse( @remote.url )
    debug 5, "Starting getForm with path #{path} - #{url.inspect}"
    debug 5, "Finished parsing #{@remote.url}"
    ret = Net::HTTP.get( url.host, "#{url.path}/merge/#{path}/#{@remote.name},#{@remote.pass}", url.port )
    debug 5, "Ending getForm with path #{path}"
    ret
  end

  def check_remote
    local_id = User.find_by_name('local').full
    debug 0, "#{local_id}"
    if ( local_id == getForm('local_id') )
      debug 0, 'Both locals have same ID'
      raise 'Same ID for local'
    end

    # Check the versions
    if ( vers = getForm('version') ) != $VERSION.to_s
      if ( vers =~ /not known/ )
        debug 0, 'Username / password not recognized'
        raise 'Wrong credentials'
      else
        debug 0, "Got version #{vers} instead of #{$VERSION.to_s}"
        raise 'Wrong version'
      end
    end
  end

  def doMerge( path, arg )
    debug 2, "arg is #{arg.inspect}"
    remote_id, s, is = "#{arg}/0/0/0/0/0/0/0/0".split( '/', 3 )
    @step = s.to_i
    @account_index_stop, @movement_index_stop,
        @got_accounts, @put_accounts,
        @got_movements, @put_movements, @put_movements_changes =
        is.split('/').collect{|i| i.to_i }

    @remote = Remote.find_by_id( remote_id )
    u = User.find_by_name('local')
    ret = nil

    case @step
      when 0
        check_remote
      when 1
        debug 1, 'Getting remotes'
        @account_index_stop = u.account_index - 1
        accounts = getForm('accounts_get')
        accounts.split("\n").each{ |a|
          acc = Account.from_s( a )
          debug 2, "Got account #{acc.name}"
          @got_accounts += 1
        }
      when 2
        # Now we can send +our_accounts+
        #@remote.account_index = 2693
        @account_index_start = @remote.account_index + 1
        if @account_index_start <= @account_index_stop
          debug 1, "Accounts to send: #{@account_index_start}..#{@account_index_stop}"
          # We have to start at the bottom, else we can get into trouble with regard
          # to children not having their parents yet...
          Account.find_all_by_account_id(0).to_a.concat(
              Account.find_all_by_account_id( nil ) ).each{|a|
            debug 2, "Root is #{a.inspect}"
            a.get_tree{|acc|
              debug( 3, "Index of #{acc.name} is #{acc.get_index}")
              if (@account_index_start..@account_index_stop) === acc.rev_index
                debug 2, "Account with index #{acc.rev_index} is being transferred"
                postForm( 'account_put', { 'account' => acc.to_s } )
                @put_accounts += 1
              end
            }
          }
        else
          debug 1, 'No accounts to send'
        end
        # Update the pointer
        @remote.update_account_index
      when 3
        debug 1, 'Getting movements'
        # Now merge the movements
        movements = getForm('movements_get')
        @movement_index_stop = u.movement_index - 1
        movements.split("\n").each{ |m|
          debug 2, "String is: \n#{m}"
          mov = Movement.from_s( m )
          @got_movements += 1
        }
      when 4
        # Now we can send +our_movements+
        @movement_index_start = @remote.movement_index + 1
        @movement_count = 0
        if @movement_index_start <= @movement_index_stop
          debug 1, "Movements to send: #{@movement_index_start}.." +
                     "#{@movement_index_stop}"
          movements = []
          Movement.find(:all, :conditions =>
                                {:rev_index => @movement_index_start..@movement_index_stop } ).each{ |m|
            movements.push( m.to_json )
            @put_movements += 1
          }
          @movement_count = movements.size
          debug 0, "Having #{movements.size} movements to send"
          while movements.size > 0
            # We'll do it by bunches of 10
            movements_put = movements.shift 10
            debug 0, 'Putting one bunch of 10 movements'
            debug 4, movements_put.to_json
            postForm( 'movements_put', {'movements' => movements_put.to_json } )
            @put_movements_changes += 1
            # TODO: remove
            # movements = []
          end
        else
          debug 1, 'No movements to send'
        end
      when 5
        # Update the pointer
        @remote.update_movement_index
        # Update the remote pointers
        getForm('reset_user_indexes')
    end

    ret = [ @account_index_stop, @movement_index_stop,
            @got_accounts, @put_accounts,
            @got_movements, @put_movements, @put_movements_changes ].join('/')
    return "#{remote_id}/#{@step + 1}/#{ret}"
  end

  def doCopied( path, arg )
    @remote = Remote.find_by_id( arg )

    check_remote

    #
    # First get the remote accounts
    u = User.find_by_name('local')
    debug 1, 'Getting remotes'
    @remote.update_account_index

    debug 1, 'Getting movements'
    @remote.update_movement_index

    debug 1, 'Asking remote to clean us'
    getForm('reset_user_indexes')
    return true
  end

end

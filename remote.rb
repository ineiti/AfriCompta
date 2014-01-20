
module Compta::Models
  # Holds the possible merge-points for putting together the pieces
  class Remote < Base;
    def set( url, name, pass )
      self.url, self.name, self.pass = url, name, pass;
      if not self.movement_index or not self.account_index
        self.movement_index = self.account_index = 0
      end
    end
    
    def update_movement_index
      self.movement_index = User.find_by_name('local').movement_index - 1
      self.save
    end
    
    def update_account_index
      self.account_index = User.find_by_name('local').account_index - 1
      self.save
    end
    
    #def self.first
    #  Remote.find(:all).first
    #end
  end
end  

module Compta::Controllers
  #
  # REMOTE-related stuff
  #
  class RemoteClasses < R '/remote/(.*)'
    def fillGlobal
      @remotes = Remote.find :all
    end
    
    def postForm( path, hash )
      debug 5, "Starting postForm with path #{path}"
      Net::HTTP.post_form( URI.parse( @remote.url + "/merge/#{path}" ), 
        { "user" => @remote.name, "pass" => @remote.pass }.merge( hash ) )
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
      if ( local_id == getForm("local_id" ) )
        debug 0, "Both locals have same ID"
        raise "Same ID for local"
      end

      # Check the versions
      if ( vers = getForm( "version" ) ) != $VERSION.to_s
        if ( vers =~ /not known/ )
          debug 0, "Username / password not recognized"
          raise "Wrong credentials"
        else
          debug 0, "Got version #{vers} instead of #{$VERSION.to_s}"
          raise "Wrong version"
        end
      end      
    end
    
    def doMerge( path, arg )
      debug 2, "arg is #{arg.inspect}"
      remote_id, s, is = "#{arg}/0/0/0/0/0/0/0/0".split( "/", 3 )
      @step = s.to_i
      @account_index_stop, @movement_index_stop,
        @got_accounts, @put_accounts,
        @got_movements, @put_movements, @put_movements_changes = 
        is.split("/").collect{|i| i.to_i }
      
      @remote = Remote.find_by_id( remote_id )
      u = User.find_by_name('local')
      ret = nil
      
      case @step
      when 0
        check_remote
      when 1
        debug 1, "Getting remotes"
        @account_index_stop = u.account_index - 1
        accounts = getForm( "accounts_get" )
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
              #              if acc.global_id == "7a32306f2cfd1d386c1d8b6d7442ef4b-1315"
              #              end
              if (@account_index_start..@account_index_stop) === acc.rev_index
                debug 2, "Account with index #{acc.rev_index} is being transferred"
                postForm( "account_put", { "account" => acc.to_s } )
                @put_accounts += 1
              end
            }
          }
        else
          debug 1, "No accounts to send"
        end
        # Update the pointer
        @remote.update_account_index
      when 3
        debug 1, "Getting movements"
        # Now merge the movements
        movements = getForm( "movements_get" )
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
            debug 0, "Putting one bunch of 10 movements"
            debug 4, movements_put.to_json
            postForm( "movements_put", {"movements" => movements_put.to_json } )
            @put_movements_changes += 1
            # TODO: remove
            # movements = []
          end
        else
          debug 1, "No movements to send"
        end
      when 5
        # Update the pointer
        @remote.update_movement_index
        # Update the remote pointers
        getForm( "reset_user_indexes" )
      end
      
      ret = [ @account_index_stop, @movement_index_stop,
        @got_accounts, @put_accounts,
        @got_movements, @put_movements, @put_movements_changes ].join("/")
      return "#{remote_id}/#{@step + 1}/#{ret}"
    end
    
    def doCopied( path, arg )
      @remote = Remote.find_by_id( arg )
      
      check_remote
      
      #
      # First get the remote accounts
      u = User.find_by_name('local')
      debug 1, "Getting remotes"
      @remote.update_account_index
      
      debug 1, "Getting movements"
      @remote.update_movement_index
      
      debug 1, "Asking remote to clean us"
      getForm( "reset_user_indexes" )
      return true
    end

    # Restrict is to compare only movements and accounts from actual year
    def doCheck( path, arg, restrict = false )
      # Tries really hard to find an account name
      def accountGet(gid)
        if ( acc = Account.find_by_global_id(gid) )
          # debug 2, "found account #{gid} locally to be #{acc.name} with path #{acc.path}"
          return acc.path
        elsif ( acc = @accounts_only_remote.select{|a| a.global_id == gid } )
          if acc.length > 0
            return acc[0].name
          else
            return gid
          end
        end
      end
      @remote = Remote.find_by_id( arg )
      
      check_remote
      
      account_max, movement_max = getForm( "index" ).split(",")
      debug 2, "maximum accounts and movements: #{[account_max, movement_max].join(':')}"
      #
      # First get the remote accounts
      
      # This is for debugging purposes - large DBs tend to take a long time
      # to list all movements 
      get_movements = true
      compare_accounts = true
      
      u = User.find_by_name('local')
      debug 1, "Getting remotes"
      @account_index_stop = u.account_index - 1
      movements_remote = ""
      # Again to not have to wait too long, we split up the transfer of big tables
      if get_movements
        (0..(movement_max.to_i / 1000 + 1).ceil).each{|pos|
          debug 2, "Getting remotes from #{pos*1000}..#{pos*1000+999}"
          if restrict
            movements_rem = getForm( "movements_get_all_actual/#{pos*1000},#{pos*1000+999}" )
          else
            movements_rem = getForm( "movements_get_all/#{pos*1000},#{pos*1000+999}" )
          end
          movements_remote += movements_rem
        }
      end
      debug 1, "Finished getting remote movements"

      if compare_accounts
        accounts_remote = []
        accounts_remote_count = getForm( "accounts_get_count" ).to_i
        pos = 0
        while ( accounts_remote.size < accounts_remote_count ) do
          accounts_remote.concat( 
            getForm( "accounts_get_part/#{pos},#{pos+999}" ).split("\n") )
          pos += 1000
        end
        
        #
        # Now find out:
        # * accounts_only_remote -  which ones are remote only, 
        # * accounts_only_local - which ones are local only
        # * accounts_empty - which ones are empty, local or remote
        remote_accounts_global_id = []
        @accounts_only_remote = []
        accounts_remote.each{ |s|
          desc, str = s.split("\r")
          if not str
            debug 0, "Invalid account found: #{desc}"
          else
            global_id, total, name, multiplier, par, 
            deleted, keep, p = str.split("\t")
            remote_accounts_global_id.push( global_id )
            if local_account = Account.find_by_global_id( global_id )
              if local_account.to_s(true) != s
                debug 1, "Remote and local are not the same."
                debug 2, "Remote: #{s.inspect}"
                debug 2, "Local : #{local_account.to_s(true).inspect}"
                local_account.update_total
              end
            else
              debug 0, "Lone remote global-id is #{global_id.inspect}"
              debug 1, str.inspect
              debug 2, "Deleted is: #{deleted}"
              if deleted == "false"
                @accounts_only_remote.push( Account.new(:name=>p, :total=>total, 
                    :global_id=>global_id, :deleted => deleted ) )
              else
                debug 2, "Ignoring because it is deleted"
              end
            end
          end
        }
        debug 2, "Remote has #{@accounts_only_remote.size} lone accounts"
      
        @accounts_only_local = Account.find(:all).select{ |a|
          if remote_accounts_global_id.index( a.global_id.to_s ) == nil
            debug 0, "Local global-id is #{a.global_id.inspect}"
            true
          else
            false
          end
        }
        debug 2, "Local has #{@accounts_only_local.size} lone accounts"
      else
        @accounts_only_remote = @acounts_only_local = []
      end
      
      #
      # And do the same for the movements:
      # * movements_only_remote
      # * movements_only_local
      remote_movements_global_id = []
      @movements_only_remote = []
      @movements_mixed = []
      if get_movements
        movements_remote.split("\n").each{ |str|
          desc, str = str.split("\r")
          if not str
            debug 0, "Invalid movement found: #{desc}"
          else
            global_id, value, date, src, dst = str.split("\t")
            remote_movements_global_id.push( global_id )
            mov = Movement.find_by_global_id( global_id )
            if not mov
              # This movement is only available on the remote system
              mov_rem = Movement.new(:desc=>desc, :value=>value, :date=>date,
                :global_id=>global_id, :src=>accountGet(src),
                :dst=>accountGet(dst))
              @movements_only_remote.push( mov_rem )
      	    else
      	      # Movement is on both systems
      	      if mov.desc != desc or
                  mov.value.to_s != value or
                  mov.date.to_s != date or
                  mov.account_src.path != accountGet(src) or
                  mov.account_dst.path != accountGet(dst)

      	        # The movements differ! Which shouldn't happen.
                mov_rem = Movement.new(:desc=>desc, :value=>value, :date=>date,
                  :global_id=>global_id, :src=>accountGet(src),
                  :dst=>accountGet(dst))
                mov.src = mov.account_src.path
                mov.dst = mov.account_dst.path
      	        @movements_mixed.push( [ mov, mov_rem ] )
      	        debug 0, "DIFFERENT MOVEMENT WITH SAME GLOBAL-ID!"
      	        debug 0, "Local is:  #{mov.global_id} - #{mov.desc} - #{mov.value.to_s} - #{mov.date.to_s} - #{mov.account_src.path} - #{mov.account_dst.path}"
      	        debug 0, "Remote is: #{global_id} - #{desc} - #{value} - #{date} - #{src} - #{dst}"
      	      end
            end
          end
        }
        debug 2, "Remote has #{@movements_only_remote.size} movements"
        #return
        
        @movements_only_local = Movement.find(:all).select{|m|
          if ( remote_id = remote_movements_global_id.index( m.global_id.to_s ) ) == nil
            m.src = m.account_src.path
            m.dst = m.account_dst.path
            true
          else
            false
          end
        }
        debug 2, "Local has #{@movements_only_local.size} own movements"
      else
        @movements_only_local = []
      end
      return true
    end
    
    # Execute the desired action
    def doCheckFix( path, arg )
      @remote = Remote.find_by_id( arg )
      
      # Kind of element to fix: movement or account
      # if it's "mixed", it should be "movement" anyway...
      @type = path.gsub( /check_fix_/, "" ) == "account" ? "account" : "movement"
      # Action: delete or copy
      @action = input.action
      # To show off once it's done
      @elements = []
      # Get all accounts, but sort them as we got them, because the
      # Hashes don't keep the order of the accounts!
      input.select{ |k,v| 
        v == "on" 
      }.sort{ |a,b|
        a[0].sub(/_.*/, '').to_i <=> b[0].sub(/_.*/, '').to_i
      }.each{|e|
        location, global_id = e[0].match(/.*_(.*)_(.*)/)[1,2]
        debug 2, [ e[0], location, global_id ].join("-")
        # The mixed movements don't have a default location, because they're
        # "wrong" on both sides...
        if location == ""
          location = @action == "pull" ? "remote" : "local"
        end 
        @elements.push("#{location} - #{global_id}")
        if location == "remote"
          debug 5, "#{location} #{@remote.url} /merge/#{@type}_#{@action} #{@remote.name}"
          case @action
          when "delete"
            # Deleting is simple
            postForm( "#{@type}_#{@action}", {"global_id" => global_id})
          when "copy", "push", "pull"
            # Copying is more complicated
            case @type
            when "account"
              account = Account.from_s( getForm("accounts_get_one/#{global_id}") )
              debug 2, "Account is #{account.to_s}"
            when "movement"
              if mdel= Movement.find_by_global_id( global_id )
                debug 2, "Found local movement: #{mdel.inspect} - deleting"
                mdel.delete
              end
              remote_str = getForm("movements_get_one/#{global_id}")
              debug 2, "Remote-str is #{remote_str.inspect}"
              movement = Movement.from_s( remote_str )
              getForm("movement_delete/#{global_id}")
              postForm( "movements_put", {"movements" => [ movement.to_json ].to_json } )
              debug 2, "Movement is #{movement.to_s}"
            end
          end
        else
          debug 2, "#{location} #{@type}_#{@action} #{global_id}"
          element = nil
          case @type
          when "account"
            element = Account.find_by_global_id( global_id )
          when "movement"
            element = Movement.find_by_global_id( global_id )
          end
          case @action
          when "delete"
            element.destroy
          when "copy", "push", "pull"
            if @type == "movement"
              # TODO: put all movements in an array
              postForm( "movements_put", {"movements" => [ element.to_json ].to_json } )
            else
              postForm( "account_put", {"account" => element.to_s } )
            end
          end
        end
      }
    end
    
    def get( p )
      fillGlobal
      path, arg = p.split("/", 2)
      case path
      when "list"
        render :remote_list
      when "add"
        @remote = Remote.new( :url => "http://localhost:3302/acaccess", :name => "ineiti", :pass => "lasj" )
        render :remote_edit
      when "delete"
        Remote.destroy( arg )
        fillGlobal
        render :remote_list        
      when "edit"
        @remote = Remote.find_by_id( arg )
        render :remote_edit
      when "check"
        begin
          doCheck( path, arg )
          render :remote_check
        rescue Exception => e
          @error = "#{e.to_s}\n#{e.backtrace.join('\n')}"
          render :remote_error
        end
      when "check_actual"
        begin
          doCheck( path, arg, true )
          render :remote_check
        rescue Exception => e
          @error = "#{e.to_s}\n#{e.backtrace.join('\n')}"
          render :remote_error
        end
      when "merge"
        begin
          @ret = doMerge( path, arg )
          @step < 5 and @refresh = [ 0, "/remote/merge/" + @ret ]
          debug 2, "refresh is #{@refresh} and ret is #{@ret.inspect}"
          render :remote_merge
        rescue Exception => e
          @error = "#{e.to_s}\n#{e.backtrace.join('\n')}"
          render :remote_error
        end
      when "copied"
        begin
          doCopied( path, arg )
          render :remote_edit
        rescue Exception => e
          @error = "#{e.to_s}\n#{e.backtrace.join('\n')}"
          render :remote_error
        end
      end
    end
    def post( p )
      path, arg = p.split("/")
      case path
      when "edit"
        r = Remote.find_or_initialize_by_id( input.rid )
        r.set( input.url, input.name, input.pass )
        r.save
        fillGlobal
        render :remote_list
      when /check_fix.*/
        doCheckFix( path, arg )
        render :remote_check_fix
      end
    end
  end
end


module Compta::Views
  
  def remote_double
    h1 "Doubling render-calls"
  end

  #
  # Remote
  #
  def remote_list
    h1 "Remotes active:"
    table do
      @remotes.to_a.each{ |r|
        tr do 
          td.small { a "Merge", :href => "/remote/merge/" + r.id.to_s }
          td.small { a "Check", :href => "/remote/check/" + r.id.to_s }
          #td.small { a "Check actual", :href => "/remote/check_actual/" + r.id.to_s }
          td.small { a "Copied", :href => "/remote/copied/" + r.id.to_s }
          td.small { a "Edit", :href => "/remote/edit/" + r.id.to_s }
          td.small { a "Delete", :href => "/remote/delete/" + r.id.to_s }
          td {
            pre r.url
          }
        end
      }
    end
    p { 
      a "Add remote", :href=> "/remote/add"
      text( "-" )
      a "Home", :href=>"/"
    }
  end
  
  def remote_edit
    form :action => "/remote/edit", :method => 'post' do
      table do
        tr{ 
          td "Remote URL"
          td { input :type => 'text', :name => "url", :value => @remote.url }
        }
        tr{ 
          td "Remote name"
          td { input :type => 'text', :name => "name", :value => @remote.name }
        }
        tr{
          td "Password"
          td { input :type => 'text', :name => "pass", :value => @remote.pass }
        }
        ["movement_index","account_index"].each{ |ind| 
          tr{
            td ind
            td { @remote[ind].to_s }
          }
        }        
      end
      input :type => 'hidden', :name => "rid", :value => @remote.id
      input :type => 'submit', :value => @remote.new_record? ? "Add remote" : "Save changes"
    end
  end
  
  def remote_merge
    if @step < 5
      h3 "Merge in progress with " + @remote.url
    else
      h3 "All done - merge is finished"
    end
    p "Checked Connection: OK"
    p "Got accounts: " + ( @step >= 1 ? @got_accounts.to_s : "Waiting" )
    p "Put accounts: " + (@step >= 2 ? @put_accounts.to_s : "Waiting")
    p "Got movements: " + (@step >= 3 ? @got_movements.to_s : "Waiting")
    p "Put movements: " + (@step >= 4 ? 
        ( "#{@put_movements} with changes: " + (@put_movements_changes).to_s ) :
        "Waiting")
    if @step < 5
      a "Interrupt merge", :href => "/movement/list"
    else
      a "Back to work", :href => "/movement/list"
    end
  end
  
  def remote_error
    h1 "Error occured, I won't merge!"
    pre @error.split( "\\n" ).join("\n")
  end
  
  def remote_check
    def put_entry( entries, str, values )
      counter = 0
      entries.each{|e|
        es = [e].flatten
        tr {
          td {
            text( "<input type=checkbox name=#{counter}_#{str}_#{es[0].global_id}" +
                " checked>" ) 
            strong str
            counter += 1
          }
          es.each{|e|
            td {
              seperator = ""
              values.each{|s|
                if s.empty?
                  br
                  seperator = ""
                else
                  text( seperator + e.send(s).to_s )
                  seperator = " - "
                end
              } } } } }
    end
    def put_table( remote, local, str, fields_remote, fields_local )
      [[remote, "remote", fields_remote],
        [local, "local", fields_local]].each{|elements, name_el, fields|
        
        p "Found #{str}s only on one side: " + ( elements.size ).to_s
        form_name = "#{str}_#{name_el}"
        table :border=>1 do
          form :action => "/remote/check_fix_#{str}/#{@remote.id.to_s}", 
          :method => "post", :name => form_name do
            put_entry( elements, name_el, fields )
            tr { td :colspan=>2 do
                input :type => "submit", :value => "Delete", 
                :onclick => "document.#{form_name}.action.value='delete'"
                input :type => "submit", :value => "Copy", 
                :onclick => "document.#{form_name}.action.value='copy'"
                input :type => 'hidden', :name => "action", :value => "none"
              end }
          end
        end      
      }
    end
    def put_table_mix( remote, str, fields_remote )
      p "Found #{str}s to be mixed-up: " + remote.size.to_s
      table :border=>1 do
        form :action => "/remote/check_fix_#{str}/#{@remote.id.to_s}", 
          :method => "post", :name => str do
          tr {
            td ""
            td "Local"
            td "Remote"
          }
          put_entry( remote, "", fields_remote )
          tr { td :colspan=>2 do
              input :type => "submit", :value => "Delete", 
              :onclick => "document.#{str}.action.value='delete'"
              input :type => "submit", :value=> "Pull",
              :onclick => "document.#{str}.action.value='pull'"
              input :type => "submit", :value=> "Push",
              :onclick => "document.#{str}.action.value='push'"
              input :type => 'hidden', :name => "action", :value => "none"
            end }
        end
      end
      
    end
    ul { 
      li {
        put_table( @accounts_only_remote, @accounts_only_local, "account",
          # Hack: Remote-accounts have their path copied into "name"
          ["name", "total", "deleted", "", "global_id"], 
          ["path", "total", "deleted", "", "global_id"] )
      }
      li {
        put_table( @movements_only_remote, @movements_only_local, "movement",
          ["date", "value", "desc", "", "src", "dst", "", "global_id"], 
          ["date", "value", "desc", "", "src", "dst", "", "global_id"] )
      }
      li {
        put_table_mix( @movements_mixed, "movement",
          ["date", "value", "desc", "", "src", "dst", "", "global_id"] )
      }
    }
    a "Home", :href=>"/"
  end
  
  def remote_check_fix
    h1 "Remote check-fix"
    p text( "Doing <strong>#{@action}</strong> on <strong>#{@type}</strong> for the following elements:" )
    ul {
      @elements.each{|a|
        li a
      }
    }
    a "Home", :href=>"/"
    b "-"
    a "Check", :href=>"/remote/check/#{@remote.id}"
  end
  
end

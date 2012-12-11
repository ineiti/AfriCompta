module Compta::Models
  
end


module Compta::Controllers
  class AdminClasses < R '/admin/(.*)'
    def get(p)
      @action, args = p.split("/")

      case @action
      when "clean"
        # Let's just test for bad accounts and movements
        @count_mov, @count_acc = 0, 0
        @bad_movements, @bad_accounts = 0, 0
        Movement.find( :all ).each{ |m|
          if not m or not m.date or not m.desc or not m.value or 
              not m.index or not m.account_src or not m.account_dst
            if m and m.desc
              debug 1, "Bad movement: #{m.desc}"
            end
            Movement.destroy(m)
            @bad_movements += 1
          end
          if m.index
            @count_mov = [ @count_mov, m.index ].max
          end
        }
        Account.find(:all).each{ |a|
          if ( a.account_id and a.account_id > 0 ) and not a.account
            Account.destroy(a)
            @bad_accounts += 1
          end
          @count_acc = [ @count_acc, a.index ].max
        }

        # Check also whether our counters are OK
        u_l = User.find_by_name('local')
        debug 1, "Movements-index: #{@count_mov} - #{u_l.movement_index}"
        debug 1, "Accounts-index: #{@count_acc} - #{u_l.account_index}"
        @ul_mov, @ul_acc = u_l.movement_index, u_l.account_index
        if @count_mov > u_l.movement_index
          debug 0, "Error, there is a bigger movement! Fixing"
          u_l.movement_index = @count_mov + 1
          u_l.save
        end
        if @count_acc > u_l.account_index
          debug 0, "Error, there is a bigger account! Fixing"
          u_l.account_index = @count_acc + 1
          u_l.save
        end
        render :clean
      end
    end
  end
end


module Compta::Views
  
  def clean
    table :border => 1 do
      if @bad_movements > 0
        p "Found #{@bad_movements} bad movements"
      else
        p "No bad movements found"
      end
      if @bad_accounts > 0
        p "Found #{@bad_accounts} bad accounts"
      else
        p "No bad accounts found"
      end
      p "Movement-indexes: #{@count_mov} < #{@ul_mov}"
      p "Account-indexes: #{@count_acc} < #{@ul_acc}"
      p { a "Home", :href => "/" }
    end
  end
  
end

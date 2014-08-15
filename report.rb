module Compta::Models
  
end

module Compta::Controllers
  class ReportCClasses < R '/report/(.*)'
    def fillGlobal
      @account_root = Account.get_root
      @account_archive = Account.get_archive
    end
    
    def get_all_sub_accounts( acc, year = nil )
      base = [ acc ]
      archive_start = year ? Account.get_path( "Archive::#{year}" ) : 
        @account_archive
      if archive_start
        debug 2, "starting account is #{archive_start.path}"
        base = []
        archive_start.get_tree{|a|
          a_path = a.path.sub(/^Archive::[0-9]*::/, '')
          acc_path = acc.path.sub(/^Root(::)*/, '')
          if a_path == acc_path
            base.push a
          end
        }
      end
      ret = []
      base.each{|a|
        a.get_tree{|b|
          ret.push b
        }
      }
      ret
    end
    
    def get_subsum_abs( account, detail )
      accounts = get_all_sub_accounts( account )
      # Double-indexed hash, first for year, then for month, containing
      # an integer...
      subsum = Hash.new{ |h,k| h[k] = Hash.new { |h,k| h[k] = 0 } }
      # First we get all values stored into the required slots
      date_start = Date.today;
      date_end = Date.today;
      accounts.each{|acc|
        acc.movements.each{ |m|
          subsum[m.date.year.to_s][m.date.method(detail).call.to_s] += m.getValue( acc )
          date_start = m.date if m.date < date_start
          date_end = m.date if m.date > date_end
        }
      }
      # Then we sum up all slots.
      sum=0
      ranges = { "cweek" => (1..53), "month" => (1..12) }
      (date_start.year..date_end.year).each {|year|
        ranges["year"] = [ year ]
        ranges[detail].each {|det|
          if ( sum = subsum[year.to_s][det.to_s] += sum ) == 0
            subsum[year.to_s][det.to_s] = 0.0001
          end
          puts "Range is #{det.to_s} for account #{account.name} and sum is #{sum}"
        }
      }
      subsum
    end
    def get_subsum_cumul( account, detail, year = nil )
      debug 3, "get_subsum_cumul for #{account.path} - with year #{year.inspect}"
      accounts = get_all_sub_accounts( account, year )

      # Double-indexed hash, first for year, then for month, containing
      # an integer...
      subsum = Hash.new{ |h,k| h[k] = Hash.new { |h,k| h[k] = 0 } }
      #return subsum
      
      accounts.each{|acc|
        acc.movements.each{ |m|
          year, month = m.date.year.to_s, m.date.method(detail).call.to_s
          if ( subsum[year][month] += m.getValue( acc ) ) == 0
            subsum[year][month] = 0.0001
          end
        }
      }
      debug 3, "Subsum is #{subsum.inspect}"
      subsum
    end
    # Calculate either a moving sum or the sum of each
    # time, up to "depth" into the tree
    def calc_subsum( type, account, detail, depth, year )
      account.subsum =
        case type
      when "abs"
        get_subsum_abs( account, detail )
      when "cumul"
        get_subsum_cumul( account, detail, year )
      end
      if depth > 0 and account.accounts_nondeleted
        account.accounts_nondeleted.each{|a|
          calc_subsum( type, a, detail, depth - 1, year )
        }
      end
    end
    def get(p)
      @type, @period, arg1, @year, @start, @depth =
        input['type'], input['period'], input['account'], 
        input['year'], input['start'], input['depth'].to_i 
      
      fillGlobal
      @show_year = @start
      if ( @period != "year" )
        if ( ( not @account_archive ) or 
              ( @account_archive.accounts_nondeleted.select{|a|
                a.name == @show_year
              }.size == 0 ) )
          @show_year = "Actual"
        end
        debug 1, "Year to show is #{@show_year}"
        @accounts = []
        if @show_year == "Actual"
          @account_root.get_tree{|a|
            @accounts.push a
          }
        else
          @account_archive.accounts_nondeleted.select{|a|
            debug 1, "Searching for year #{@show_year} in #{a.name}"
            a.name == @show_year.to_s
          }.first.get_tree{|a|
            @accounts.push a
          }
        end
      else
        @accounts = []
        @account_root.get_tree{|a| @accounts.push a}
        @account_archive.get_tree{|a| @accounts.push a}
      end
      if arg1
        @account = Account.find_by_id( arg1 )
        if not @accounts.index( @account )
          path = @account.path.gsub(/^Root::/, '')
          path.gsub!(/^Archive::[^:]*(::)*/, '')
          debug 1, "Changed year - searching account with path #{path}"
          @account = @accounts.select{|a|
            a.path =~ /#{path}$/
          }.first
        end
      else
        @account = @accounts[0]
      end
      @movements = @account.movements
      
      not @year and @year = Date.today.year.to_s
      not @depth and @depth = 2
      
      # Make a hashed array with the sub-accounts as key and the
      # months as index
      debug 1, "Period is: #{@period} - year is #{@year.inspect}"
      calc_subsum( @type, @account, @period, @depth + 1, @year)
      @parent = @account.account
      
      case @period
      when "year"
        # Let's make a flag out of year
        @year = 0
        @last = 9999
        not @start and @start = Date.today.year.to_s
      when "month"
        @last = 12
        not @start and @start = Date.today.month.to_s
      when "cweek"
        # Well, this is trial and error and has something to do with
        # the commercial week. It gives the last cweek in a year.
        @last = Date.parse( "#{@year}-12-28" ).cweek
        not @start and @start = Date.today.cweek.to_s
      end
      if @depth > 0
        render :report_tree_accounts
      else
        render :report_accounts
      end
    end
  end
end

module Compta::Views
  
  def previous_arrays( n )
    y, s = @year, @start
    n.downto(1){|i|
      if y.to_i > 0
        yield y, s
      else
        yield s, s
      end
      s = ( s.to_i - 1 ).to_s
      if s == '0'
        s = @last.to_s
        y = ( y.to_i - 1 ).to_s
      end
    }
  end
  
  def show_sum( h, show_total = false )
    total = 0
    previous_arrays( 12 ){|y, p|
      total += h[y][p]
    }
    sub_total = total
    previous_arrays( 12 ){|y, p|
      now = h[y][p]
      td.money {
        if show_total
          sub_total.fix(0, 3)
        else
          now.fix( 0, 3 )
        end
      }
      sub_total -= now
    }
    return total
  end
  
  def print_link_type( t, a = @account, y = @year, 
      s = @start, d = @depth )
    if @period == "year" and y == 0
      y = s
    end
    "/report/?type=#{t}&period=#{@period}&" +
      "account=#{a.id}&year=#{y}&start=#{s}" +
      ( d > 0 ? "&depth=#{d}" : "" )
  end
        
  def print_link(a, y = @year, s = @start, d = @depth )
    print_link_type( @type, a, y, s, d )
  end
  
  def get_accounts_depth( acc, depth )
    sub_accounts = [ [ acc, depth ] ]
    if depth > 0 and acc.accounts_nondeleted
      acc.accounts_nondeleted.sort{|a,b|
        a.name <=> b.name }.each{|a|
        sub_accounts.concat( get_accounts_depth( a, depth - 1) )
      }
    end
    return sub_accounts
  end
  
  def report_tree_accounts
    table :border => 1 do
      # Go home
      a "Home", :href => "/"
      b ":"
      a "+++", :href => print_link( @account, @year, @start,
        @depth + 3 )
      b ":"
      a "++", :href => print_link( @account, @year, @start,
        @depth + 2 )
      b ":"
      a "+", :href => print_link( @account, @year, @start,
        @depth + 1 )
      b ":"
      a "-", :href => print_link( @account, @year, @start,
        @depth - 1 )
      b ":"
      a "--", :href => print_link( @account, @year, @start,
        @depth - 2 )
      b ":"
      a "---", :href => print_link( @account, @year, @start,
        @depth - 3 )
      b ":"
      s = @start.to_i - 1
      a s, :href => print_link( @account, s, s )
      b "-"
      s = @start.to_i + 1
      a s, :href => print_link( @account, s, s )

      # Heading
      tr {
        td "Account"
        @depth.downto(0){
          td "Subsum"
        }
      }
      
      # Accounts
      first = true
      get_accounts_depth( @account, @depth ).each{|a|
        acc, level = a
        if acc.subsum[@start][@start] != 0
          tr {
            # Print a nice name in pseudo-tree manner
            name = "+" + "-" * ( @depth - level ) + acc.name
            td {
              if first
                a name, :href => print_link( @parent )
                first = false
              else
                a name, :href => print_link( acc )
              end
            }
            # Fill non-used cells with spaces
            level.upto(@depth-1){|l|
              td ""
            }
            td.money {
              acc.subsum[@start][@start].fix(0, 3)
            }
          }
        end
      }
    end
  end
  
  def report_accounts
    # The movements
    table :border => 1 do
      # Go home
      a "Home", :href => "/"
      b "-"
      if @type == "cumul"
        a "absolu", :href => print_link_type( "abs" )
      else
        a "cumul", :href => print_link_type( "cumul" )
      end
      # Print the periods
      tr {
        td "Account"
        previous_arrays( 12 ){|y, p|
          if @year.to_i > 0
            #            td.money :width => "7%" do
            td.money do
              # Prepare first for putting the chosen period at the left
              first = "#{y}/#{p}"
              # Prepare last for putting the chosen period at the right
              # Fix: for the 0th period, it is in fact the previous year. This
              # is why we do only "+10", but add one to the "last2"
              last1, last2 = (y.to_i * @last.to_i + p.to_i + 10).divmod(@last.to_i)
              last = "#{last1}/#{last2 + 1}"
              a "|<", :href => print_link( @account, y, p )
              a ">|", :href => print_link( @account, last1, last2 + 1 )
              br "#{y}/#{p}"
            end
          else
            td y, :width => "7%"
          end
        }
        if @type == "cumul"
          td "Sum"
        end
      }
      tr {
        td {
          if @parent
            a @account.name, :href => print_link( @parent )
          else
            @account.name
          end
        }
        # Show the 12 last months
        total = show_sum( @account.subsum )
        if @type == "cumul"
          td.money total.fix( 0, 3 )
        end
      }
      @account.accounts_nondeleted.sort{|a,b| a.name <=> b.name}.
        reverse.each {|acc|
        tr {
          td {
            a "+-#{acc.name}", 
            :href => print_link( acc )
          }
          # Show the 12 last months
          if acc.subsum
            total = show_sum( acc.subsum )
            if @type == "cumul"
              td.money total.fix( 0, 3 )
            end
          end
        }
      }
      if @type == "cumul"        
        tr { td "" }
        tr {
          td "Cumulé"
          total = show_sum( @account.subsum, true )
          td.money total.fix( 0, 3 )
        }
      end
    end
  end
  
end

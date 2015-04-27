module Compta::Models
  class Movement < Base;
    belongs_to :account_src, :class_name => 'Account', :foreign_key => 'account_src_id'
    belongs_to :account_dst, :class_name => 'Account', :foreign_key => 'account_dst_id'
    attr_writer :src, :dst
    attr_reader :src, :dst

    def new_index
      u_l = User.find_by_name('local')
      self.rev_index = u_l.movement_index
      u_l.movement_index += 1
      u_l.save
      debug 3, "index is #{self.rev_index} and date is --#{self.date}--"
      debug 3, "User('local').rev_index is: " + User.find_by_name('local').movement_index.to_s
      debug 3, "global_id is #{self.global_id}"
    end

    def get_index
      return self.rev_index
    end

    def is_in_account(a)
      return (a == account_src or a == account_dst)
    end

    def value=(v)
      if account_src and account_dst
        debug 3, 'value=' + v.to_s + ':' + account_src.total.to_s
        diff = value.to_f - v
        account_src.total = account_src.total.to_f + (diff * account_src.multiplier)
        account_dst.total = account_dst.total.to_f - (diff * account_dst.multiplier)
      end
      new_index
      super(v)
    end

    def getValue(account)
      value.to_f * account.multiplier.to_f * (account_src == account ? -1 : 1)
    end

    def getOtherAccount(account)
      account_src == account ? account_dst : account_src
    end

    def self.date_from_s(d_str)
        # Do some date-magic, so that we can give either the day, day and month or
        # a complete date. The rest is filled up with todays date.
        date = d_str.split('/')
        da = Date.today
        d = [da.day, da.month, da.year]
        date += d.last(3 - date.size)
        if date[2].to_s.size > 2
          Date.strptime(date.join('/'), '%d/%m/%Y')
        else
          Date.strptime(date.join('/'), '%d/%m/%y')
        end
    end

    def set(desc, date, value, source, dest)
      debug 3, 'self.value ' + self.value.to_s + ' - ' + value.to_s
      self.value = 0
      self.account_src, self.account_dst =
          Account.find_by_id(source), Account.find_by_id(dest)
      if true
        self.date = Movement.date_from_s(date)
      else
        self.date = Date.from_s(date)
      end
      self.desc, self.value = desc, value
      debug 4, 'Going to save'
      new_index
      save
      debug 4, 'Date ' + self.date.to_s
    end

    def Movement.create(desc, date, value, source, dest)
      return nil if source == dest
      t = Movement.new(:value => 0, :account_src => Account.find_by_id(source),
                       :account_dst => Account.find_by_id(dest))
      t.save
      t.global_id = User.find_by_name('local').full + '-' + t.id.to_s
      t.set(desc, date, value, source, dest)
      t
    end

    def destroy
      self.delete
    end

    def to_s
      "#{desc}\r#{global_id}\t" +
          "#{value.to_s}\t#{date.to_s}\t" +
          account_src.global_id.to_s + "\t" +
          account_dst.global_id.to_s
    end

    def to_json
      ActiveSupport::JSON.encode(:str => to_s)
    end

    def Movement.from_json(str)
      Movement.from_s(ActiveSupport::JSON.decode(str)['str'])
    end

    def Movement.from_s(str)
      desc, str = str.split("\r")
      global_id, value, date, src, dst = str.split("\t")
      debug 3, "Movement #{desc} - #{str}"
      date = Time.parse(date).to_ss
      value = value.to_f
      a_src = Account.find_by_global_id(src)
      a_dst = Account.find_by_global_id(dst)
      if not a_src or not a_dst
        debug 0, "error: didn't find " + src.to_s + ' or ' + dst.to_s
        return [-1, nil]
      end
      # Does the movement already exist?
      our_m = nil
      if not (our_m = Movement.find_by_global_id(global_id))
        debug 3, 'New movement'
        our_m = Movement.new
        our_m.global_id = global_id
      else
        debug 2, "Overwriting movement #{global_id}"
      end
      # And update it
      our_m.set(desc, date, value, a_src.id, a_dst.id)
      our_m.save
      return our_m
    end
  end
end


module Compta::Controllers
  #
  # MOVEMENT-related stuff
  #
  class MovementClasses < R '/movement/(.*)'
    def fillGlobal(show_year = 'Actual')
      if show_year == 'Actual'
        @account_root = Account.get_root
      else
        @account_root = Account.get_archive.accounts.select { |a|
          a.name == show_year
        }.first
      end
      @show_year = show_year
      debug 0, "Found root-account #{@account_root} for year #{@show_year}"
      @accounts = []
      @account_root.get_tree { |a| a.deleted or @accounts.push(a) }
      @account_archive = Account.get_archive
      @remote = Remote.first
      #      @account_lm = Account.find_by_id( 150 )
    end

    def movements_sort(arg)
      @sort = arg
      debug 0, "sorting movements according to #{arg.inspect}"
      case arg
        when 'account'
          @movements.sort! { |a, b|
            a.getOtherAccount(@account).name <=> b.getOtherAccount(@account).name
          }
        when /value.*/
          mult = (arg == 'valued' ? 1 : -1) * @account.multiplier
          @movements.sort! { |a, b|
            (a.getValue(@account) <=> b.getValue(@account)) * mult
          }
        else
          @movements.sort! { |a, b|
            a[arg] <=> b[arg]
          }
      end
    end

    def get_dates(inp)
      if inp.date_from and inp.date_to
        @date_from, @date_to =
            Date.from_s(inp.date_from), Date.from_s(inp.date_to)
        debug 0, "inp.date_from.length = #{inp.date_from.length}"
        if inp.date_from.length == 0
          @date_from = Date.from_s('1/1/1900')
        end
        if inp.date_to.length == 0
          @date_to = Date.from_s('31/12/9999') # I hope He's back by then!
        end
      else
        @date_from = Date.from_s('1/1/0')
        @date_to = Date.from_s('31/12/9999')
      end
      debug 4, "From: #{@date_from} to: #{@date_to}"
    end

    def get(p)
      path, arg1, arg2, arg3 = p.split('/')
      @movement = Movement.new(:date => Time.now)
      debug 2, "input is #{input.inspect}"
      p RUBY_VERSION
      show_year = arg1 || 'Actual'
      if arg2
        @account = Account.find_by_id(arg2)
      else
        @account = Account.find_all_by_account_id(0)[0]
      end
      get_dates(input)
      @movements = @account.movements(@date_from, @date_to)
      case path
        when 'list'
          if @movements[0]
            @movement.account_src = @movements[0].account_src
            @movement.account_dst = @movements[0].account_dst
          end
        when 'edit'
          @movement = Movement.find_by_id(arg3)
        when 'del'
          mov = Movement.find_by_id(arg3)
          debug 1, "Deleting movement #{mov.to_s.inspect}"
          @movements.delete(mov)
          mov.value = 0
          mov.new_index
          mov.save
        when 'inverse'
          @movements.each { |m|
            m.account_src, m.account_dst = m.account_dst, m.account_src
            m.new_index
            m.save
          }
        when 'get_sum'
          sum_c, sum_d = 0, 0
          @account.movements.to_a.each { |m|
            if m.account_src == @account
              sum_d += m.value.to_f
            else
              sum_c += m.value.to_f
            end
          }
          return ActiveSupport::JSON.encode([sum_d, sum_c, @account.multiplier])
      end
      fillGlobal(show_year)
      movements_sort(input['sort']) if input['sort']
      render :movement_list
    end

    def post(p)
      path, arg = p.split('/')
      debug 2, "input is #{input.inspect}"
      in_cred = eval input.credit.to_s
      in_deb = eval input.debit.to_s
      credit = in_cred.to_f - in_deb.to_f
      account_src, account_dst =
          input.account_src, input.account_dst
      show_year = input.show_year || 'Actual'
      @account = Account.find_by_id(account_src)
      if credit > 0
        account_src, account_dst = account_dst, account_src
      end
      debug 1, 'post: src, dst ' + account_src.to_s + ':' + account_dst.to_s
      #      m = @account.movements[0]
      get_dates(input)
      debug 2, "For #{path} with #{arg}"

      fillGlobal(show_year)
      case path
        when 'edit'
          mov = Movement.find_or_initialize_by_id(input.mid)
          mov.new_index()
          mov.set(input.desc, input.date,
                  credit.abs, account_src, account_dst)
          debug 3, 'Setting ' + input.mid + ' to ' + credit.to_s
        when 'add'
          p input.date
          #date = Date.strptime(input.date, '%d/%m/%y')
          date = Movement.date_from_s(input.date)
          if date > Date.today
            debug 3, "In future: #{date} for #{Date.today}"
            date = Date.today
          elsif date < Date.today - 31
            debug 3, "Too early: #{date} smaller than #{Date.today - 31}"
            date = Date.today
          end
          mov = Movement.create(input.desc, date.strftime('%d/%m/%Y'),
                                credit.abs, account_src, account_dst)
          if arg == 'silent'
            return nil
          end
        when 'list'
          if not @accounts.index(@account)
            @account = @account_root
          end
          mov = @account.movements[0]
        when 'multi'
          multi_mov = []
          @account.movements.each { |m|
            if input[m.id.to_s] == 'on'
              multi_mov.push(m)
            end
          }
          case input.action
            when 'move'
              multi_mov.each { |m|
                debug 2, "Moving movement #{m.id} - #{m.desc}"
                value = m.value
                m.value = 0
                if m.account_src.id.to_s == account_src
                  debug 3, "Changing src to #{account_dst}"
                  m.account_src = Account.find_by_id(account_dst)
                else
                  debug 3, "Changing dst to #{account_dst}"
                  m.account_dst = Account.find_by_id(account_dst)
                end
                m.new_index
                m.value = value.to_f
                m.save
              }
            when 'delete'
              multi_mov.each { |m|
                debug 2, "Deleting movement #{m.id}"
                m.value = 0
                m.new_index
                m.save
              }
            when 'inverse'
              multi_mov.each { |m|
                debug 2, "Inversing movement #{m.id}"
                value = m.value
                m.value = 0
                m.account_src, m.account_dst = m.account_dst, m.account_src
                m.value = value.to_f
                m.new_index
                m.save
              }
          end
          @account = Account.find_by_id(account_src)
        else
          mov = @account.movements[0]
      end
      if not mov
        mov = Movement.new(:date => Date.today)
      end
      @movements = @account.movements(@date_from, @date_to)
      @movement = Movement.new(:date => mov.date,
                               :account_dst => mov.account_dst, :account_src => mov.account_src)
      movements_sort(input['sort']) if input['sort']
      render :movement_list
    end
  end
end

CPATH='/'

module Compta::Views
  #
  # Movement
  #
  def movement_table_entry(m, account, total)
    value = m.value.to_f.fix(0, 3)
    if value != '0.000'
      acc, deb, cred = nil, '', ''
      if m.account_src == account
        acc, deb = m.account_dst, value
      else
        acc, cred = m.account_src, value
      end
      cred_deb = "<td><a href='#{CPATH}movement/list/#{@show_year}/#{acc.id}'>"+
          "#{acc.name}</a></td>" +
          "<td class='money'>#{cred}</td><td class='money'>#{deb}</td>"
      args = "#{@show_year}/#{account.id.to_s}/#{m.id.to_s}"
      text("<tr><td><input type=checkbox name=#{m.id}></td>"+
               "<td>#{m.date.to_s_eu}</td>" +
               "<td>#{m.desc}</td>#{cred_deb}" +
               "<td><a href=\"#{CPATH}movement/edit/#{args}\">edit</a> " +
               "<a href=\"#{CPATH}movement/del/#{args}\">del</a></td>" +
               "<td>#{total.fix(0, 3)}</td>" +
               '</tr>')
      if m.account_src == account
        total += m.value.to_f * account.multiplier
      else
        total -= m.value.to_f * account.multiplier
      end
    end
    total
  end

  def movements_table_headers(account)
    # Headers
    tr {
      # Inverts the selection of the checkboxes
      td :onclick => "
              for (i=0;i<document.multi.elements.length;i++){
              current = document.multi.elements[i];
              if ( current.type == 'checkbox' ){
                current.checked = ! current.checked;
              } }" do
        'Inv'
      end

      url = "#{CPATH}movement/list/#{@show_year}/#{@account.id}?date_from=#{@date_from}&date_to=#{@date_to}&sort="
      td { a 'Date', :href => "#{url}date" }
      td { a 'Description', :href => "#{url}desc" }
      td { a 'Account', :href => "#{url}account" }
      if account.multiplier == 1
        td { a 'Créditer ici', :href => "#{url}valuec" }
        td { a 'Débiter ici', :href => "#{url}valued" }
      else
        td { a 'Débiter ici', :href => "#{url}valuec" }
        td { a 'Créditer ici', :href => "#{url}valued" }
      end
      td ''
      td 'Total'
    }
  end

  def name_rec(acc, str = '')
    if acc.account
      str = str + name_rec(acc.account, str) + '::'
    end
    str += "<a href='#{CPATH}movement/list/#{@show_year}/#{acc.id}'>#{acc.name}</a>"
  end

  def sum_accounts(acc)
    ret = acc.total.to_f
    acc.accounts_nondeleted.to_a.each { |a|
      ret += sum_accounts(a)
    }
    ret
  end

  def list_accounts(name, selected)
    select :name => name, :size => '1' do
      list_sub([@account_root]) { |acc, str|
        sel = (acc == selected ? ' selected' : '')
        text("<option value=\"#{acc.id.to_s}\"#{sel}>" +
                 "#{str}</option>")
      }
    end
  end

  def list_years
    select :name => :show_year, :size => '1' do
      years = %w( Actual )
      if @account_archive
        years += @account_archive.accounts.collect { |a| a.name }
      end
      years.sort.reverse.each { |a|
        text("<option value=\"#{a}\"#{a == @show_year ? ' selected' : ''}>" +
                 "#{a}</option>")

      }
    end
  end

  def movement_list
    perf_mov = PerformanceClass.new
    # Everybody loves tables for layout
    table :border => 1 do
      tr {
        a 'Home', :href => "#{CPATH}"
        b '-'
        a 'Accounts', :href => "#{CPATH}account/list"
        if @remote
          b '-'
          a 'Merge with base', :href => "#{CPATH}remote/merge/#{@remote.id}"
        end
        td :align => 'center' do
          text("<h1>#{ name_rec(@account) }</h1>")
          p {
            @account.accounts_nondeleted.each { |a|
              a a.name, :href => "#{CPATH}movement/list/#{@show_year}/#{a.id}"
            }
          }
          # List of accounts
          perf_mov.timer_start

          form :action => "#{CPATH}movement/list", :method => 'post' do
            list_years
            list_accounts('account_src', @account)
            input :type => 'text', :name => 'date_from', :size => '10', :value => @date_from.to_s_eu
            input :type => 'text', :name => 'date_to', :size => '10', :value => @date_to.to_s_euy
            input :type => 'hidden', :name => 'sort', :value => @sort if @sort
            input :type => 'submit', :value => 'Afficher'
          end
          perf_mov.timer_read('Writing accounts: ')
        end
      }
      tr :valign => 'top' do
        td {
        }
      end
      tr {
        # The movements in a table:
        # tr - Headers
        # tr - Form for new movements or editing
        # trs - The movements
        td {
          table :border => 1 do
            movements_table_headers(@account)
            # A form for a new movement
            action = @movement.new_record? ? 'add' : 'edit'
            form :action => "#{CPATH}movement/" + action, :method => 'post' do
              tr {
                td ''
                td { input :type => 'text', :name => 'date', :size => '10',
                           :value => @movement.date.strftime('%d/%m/%y') }
                td { input :type => 'text', :name => 'desc', :size => '40',
                           :value => @movement.desc }
                if @movement.account_src == @account
                  td { list_accounts('account_dst', @movement.account_dst) }
                  credit, debit = 0, @movement.value
                else
                  td { list_accounts('account_dst', @movement.account_src) }
                  credit, debit = @movement.value, 0
                end
                td { input :type => 'text', :name => 'credit', :size => '10',
                           :value => credit }
                td { input :type => 'text', :name => 'debit', :size => '10',
                           :value => debit }
                input :type => 'hidden', :name => 'account_src', :value => @account.id
                input :type => 'hidden', :name => 'show_year', :value => @show_year
                submit = 'New movement'
                if not @movement.new_record?
                  input :type => 'hidden', :name => 'mid',
                        :value => @movement.id
                  submit = 'Update'
                end
                input :type => 'hidden', :name => 'sort', :value => @sort if @sort
                td { input :type => 'submit', :value => submit }
              }
            end
            perf_mov.timer_read('Preparing edit-fields: ')

            # The movements
            form :action => "#{CPATH}movement/multi", :method => 'post', :name => 'multi' do
              sum_c, sum_d = 0, 0
              @movements.to_a.each { |m|
                if m.account_src == @account
                  sum_d += m.value.to_f
                else
                  sum_c += m.value.to_f
                end
              }
              total = (sum_c - sum_d) * @account.multiplier
              @movements.to_a.each { |m|
                total = movement_table_entry(m, @account, total)
              }
              perf_mov.timer_read('Movements: ')
              tr {
                td :colspan => '8' do
                  list_accounts('account_dst', nil)
                  input :type => 'submit', :value => 'Move',
                        :onclick => "document.multi.action.value='move'"
                  input :type => 'submit', :value => 'Delete',
                        :onclick => "document.multi.action.value='delete'"
                  input :type => 'submit', :value => 'Inverse',
                        :onclick => "document.multi.action.value='inverse'"
                  input :type => 'hidden', :name => 'account_src', :value => @account.id
                  input :type => 'hidden', :name => 'action', :value => 'none'
                  input :type => 'hidden', :name => 'show_year', :value => @show_year
                end
              }
              perf_mov.timer_read('Total time for page: ', false)
            end
          end
        }
      }
    end
    a 'Home', :href => "#{CPATH}"
    b '-'
    a 'Accounts', :href => "#{CPATH}account/list"
    if @remote
      b '-'
      a 'Merge with base', :href => "#{CPATH}remote/merge/#{@remote.id}"
    end
  end
end

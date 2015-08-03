class ComptaCheck < View
  def layout
    @order = 50
    gui_vbox do
      gui_hbox :nogroup do
        gui_vbox :nogroup do
          show_int_ro :accounts_only_db
          show_int_ro :accounts_only_server
          show_int_ro :accounts_mixed
        end
        gui_vboxg :nogroup do
          show_table :accounts, :headings => [:Check, :Name, :Total],
                     :widths => [100, 300, 75], :height => 400,
                     :columns => [0, 0, :align_right]
          show_button :accounts_delete, :accounts_copy
        end
      end

      gui_hbox :nogroup do
        gui_vbox :nogroup do
          show_int_ro :movements_only_db
          show_int_ro :movements_only_server
          show_int_ro :movements_mixed

        end
        gui_vboxg :nogroup do
          show_table :movements, :headings => [:Check, :Date, :Desc, :Value, :Src, :Dst],
                     :widths => [100, 100, 300, 100, 100, 100], :height => 400,
                     :columns => [0, 0, 0, :align_right, 0, 0], :flexwidth => 1
          show_button :movements_delete, :movements_copy
        end
      end

      gui_hbox :nogroup do
        show_upload :upload_db, :callback => true
      end

      gui_window :progress do
        show_html :progress_txt
        show_button :close, :continue
      end
    end
  end

  def check_split(arr)
   [arr[0].collect { |a| a.split(/[\r\t]/) },
        arr[1].collect { |a, b|
          [a.split(/[\r\t]/),
           b.split(/[\r\t]/)]
        },
        arr[2].collect { |a| a.split(/[\r\t]/) }]
  end

  def start_thread(session, mod)
    session.s_data._check_module = mod
    Thread.start {
      System.rescue_all do
        case mod
          when /Accounts/
            dputs(2) { 'Starting check_accounts' }
            session.s_data._check_accounts =
                check_split(orig = Accounts.check_against_db(session._s_data._filename))
            session.s_data._check_accounts_orig = orig
          when /Movements/
            dputs(2) { 'Starting check_movements' }
            session.s_data._check_movements =
                check_split(orig = Movements.check_against_db(session._s_data._filename))
            session.s_data._check_movements_orig = orig
        end
      end
    }
    sleep 1
  end

  def get_accounts(accounts, row)
    accounts.each { |a|
      row[a] = (acc = Accounts.match_by_global_id(row[a])) ? acc.name : 'nil'
    }
    row
  end

  def collect_table(id, check, rows, cols, accounts = [])
    level = check.class == String ? 0 : 1
    counter = 0
    rows.collect { |r|
         counter += 1
         if check.class == String
           c = get_accounts(accounts, r)
           ["#{id},#{counter}", cols.collect { |col_nbr| c[col_nbr] }.unshift(check)]
         else
           c1 = get_accounts(accounts, r[0])
           c2 = get_accounts(accounts, r[1])
           [["#{id},#{counter}", cols.collect { |col_nbr| c1[col_nbr] }.unshift(check[0])],
               ["#{id},#{counter}", cols.collect { |col_nbr| c2[col_nbr] }.unshift(check[1])]]
         end
       }.flatten(level)
  end

  def update_counters_tables(session, data)
    accs, movs = session.s_data._check_accounts, session.s_data._check_movements
    dputs(2) { "Done. accs, movs = #{accs.collect { |a| a.size }} - "+
        "#{movs.collect { |m| m.size }}" }
    reply(:window_hide) +
        reply(:auto_update, 0) +
        reply(:update, accounts_only_db: accs[0].size, accounts_only_server: accs[2].size,
              accounts_mixed: accs[1].size,
              movements_only_db: movs[0].size, movements_only_server: movs[2].size,
              movements_mixed: movs[1].size) +
        reply(:update, accounts: collect_table(0, 'File only', accs[0], [3, 2]) +
                         collect_table(2, 'Server only', accs[2], [3, 2]) +
                         collect_table(1, ['Mix - File', 'Mix - Server'], accs[1], [3, 2]),
              movements: collect_table(0, 'File only', movs[0], [3, 0, 2, 4, 5], [4, 5]) +
                  collect_table(2, 'Server only', movs[2], [3, 0, 2, 4, 5], [4, 5]) +
                  collect_table(1, ['Mix - File', 'Mix - Server'], movs[1], [3, 0, 2, 4, 5], [4, 5]))
  end

  def rpc_update_with_values(session, data)
    state, progress = case mod = session.s_data._check_module
                        when /Accounts/
                          [Accounts.check_state, Accounts.check_progress]
                        when /Movements/
                          [Movements.check_state, Movements.check_progress]
                        else
                          ['Error', 0]
                      end
    dputs(3) { "Found module #{mod} with state #{state}: #{progress}" }
    ret = reply(:update, :progress_txt => "#{mod}: #{state} - #{(progress * 100).floor}%")
    if state == 'Done'
      if mod == :Accounts
        dputs(2) { 'Module Accounts done, starting Movements' }
        start_thread(session, :Movements)
      else
        ret += update_counters_tables(session, data)
      end
    end
    ret
  end

  def rpc_button_upload_db(session, data)
    session._s_data._filename = "/tmp/#{UploadFiles.escape_chars(data._filename)}"
    reply(:window_show, :progress) +
        reply(:update, progress_txt: "Uploaded file #{session._s_data._filename}") +
        reply(:unhide, :continue) +
        rpc_button_continue(session, data)
  end

  def rpc_button_continue(session, data)
    start_thread(session, :Accounts)
    reply(:auto_update, -1) +
        reply(:update, progress_txt: 'Starting checking') +
        reply(:hide, :continue)
  end

  def get_entities(ent, rows, table, gid)
    table.collect { |t|
         r, ind = t.split(',').collect { |i| i.to_i }
         [r, ind-1, if r == 1
                      ent.match_by_global_id(rows[r][ind-1][1][gid])
                    else
                      ent.match_by_global_id(rows[r][ind-1][gid])
                    end]
       }
  end

  def action(session, ent, table, what)
    case ent.to_s
      when /Movements/
        rows = session.s_data._check_movements
        rows_orig = session.s_data._check_movements_orig
      when /Accounts/
        rows = session.s_data._check_accounts
        rows_orig = session.s_data._check_accounts_orig
    end
    gid = ent == Movements ? 1 : 1
    msgs = []
    get_entities(ent, rows, table, gid).
        each { |source, ind, e|
      case ent.to_s
        when /Movements/
          case what
            when :copy
              case source
                when 0
                  mov = Movements.from_s(rows_orig[0][ind])
                  msgs.push "Created movement #{mov.desc}"
                when 1
                  mov = Movements.from_s(rows_orig[1][ind][0])
                  msgs.push "Created movement #{mov.desc}"
                when 2
                  e.new_index
                  msgs.push "Updated index of #{e.desc}"
              end
            when :delete
              if source > 0
                e.delete
                msgs.push 'Deleted movement'
              else
                msgs.push "Didn't delete movement from file"
              end
          end
        when /Accounts/
          case what
            when :copy
              if source == 0
                acc = Accounts.from_s(rows_orig[0][ind])
                msgs.push "Copied account #{acc.name} from file"
              else
                msgs.push "Didn't copy account from server to file or clean-up mixed"
              end
            when :delete
              if source > 0
                if e.is_empty
                  e.delete
                  msgs.push "Deleted account #{e.get_path}"
                else
                  msgs.push "Account #{e.get_path} is not empty"
                end
              else
                msgs.push "Can't delete account in file"
              end
          end
      end
    }
    reply(:window_show, :progress) +
        reply(:update, progress_txt: "Done. Msgs:<br><pre>#{msgs.join("\n")}</pre>") +
        reply(:hide, :continue)
  end

  def rpc_button_movements_copy(session, data)
    action(session, Movements, data._movements, :copy)
  end

  def rpc_button_movements_delete(session, data)
    action(session, Movements, data._movements, :delete)
  end

  def rpc_button_accounts_copy(session, data)
    action(session, Accounts, data._accounts, :copy)
  end

  def rpc_button_accounts_delete(session, data)
    action(session, Accounts, data._accounts, :delete)
  end

end
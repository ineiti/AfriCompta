class ReportComptaExecutive < View
  include PrintButton

  def layout
    @order = 20
    @update = true
    @functions_need = [:accounting]

    gui_hboxg do
      gui_vbox :nogroup do
        gui_vboxg :nogroup do
          show_entity_report_all :reports, :single, :name, :callback => true,
                                 :flexheight => 1
          show_button :report_add, :report_delete
        end
        gui_vbox :nogroup do
          show_date :start
          show_int :months
          show_print :print
        end
      end
      gui_vboxg :nogroup do
        show_str :name
        show_entity_reportAccount :accounts, :single,
                                  :flexheight => 1, :width => 300
        show_button :account_add, :account_del, :account_edit
        show_button :account_up, :account_down
      end

      gui_window :win_account do
        gui_vbox :nogroup do
          show_entity_account :root, :drop, :width => 400,
                              :callback => true
          show_entity_account :account, :drop
          show_int :level
          show_button :account_add_win, :account_save_win, :close
        end
      end

      gui_window :win_report do
        show_str :report_name
        show_button :report_add_win, :close
      end

      gui_window :progress do
        show_html :progress_txt
        show_button :report_cancel
      end

      window_print_status
    end
  end

  def rpc_button_report_add(session, data)
    reply(:window_show, :print_status)
  end

  def update_account(root = AccountRoot.actual, account = nil)
    reply(:empty, :account) +
        reply(:update, :account => root.listp_path) +
        reply(:update, :account => [(account.class == Account) ? account.id : 0])
  end

  def update_root(root = AccountRoot.actual)
    roots = [[AccountRoot.actual.id, 'Actual']]
    archive = AccountRoot.archive and roots.concat(archive.listp_path(1)[1..-1])
    reply(:empty, :root) +
        reply(:update_silent, :root =>
                                roots.concat([(root.class == Account) ? root.id : 0]))
  end

  def update_reports
    reply(:empty, :reports) +
        reply(:update, :reports => Reports.listp_name)
  end

  def update_report(report, account = nil)
    reply(:empty, :accounts) +
        reply(:update, :name => report.name) +
        reply(:update, :accounts => report.listp_accounts) +
        reply(:update, :accounts => (account.class == ReportAccount) ?
                         [account.id] : nil)
  end

  def rpc_update(session)
    td = Date.today
    # Start in beginning of semester
    start = Date.new(td.year, (td.month / 7.0).floor * 6 + 1)
    update_reports +
        reply(:update, :start => start.to_web) +
        reply(:update, :months => 6) +
        reply_print(session)
  end

  def button_account(session, name, data)
    return if data._reports == []

    case name
      when /add_win/
        data._reports.accounts = data._reports.accounts +
            [ReportAccounts.create(data)]
        update_report(data._reports) +
            reply(:window_hide)
      when /add/
        reply(:window_show, :win_account) +
            update_account +
            update_root +
            reply(:update, :level => "1") +
            reply_show_hide(:account_add_win, :account_save_win)
      when /del/
        return if data._accounts == []
        data._reports.accounts = data._reports.accounts.reject { |a|
          a == data._accounts
        }
        update_report(data._reports)
      when /edit/
        return if data._accounts == []
        reply(:window_show, :win_account) +
            update_root(data._accounts.root) +
            update_account(data._accounts.root, data._accounts.account) +
            reply(:update, :level => data._accounts.level) +
            reply_show_hide(:account_save_win, :account_add_win)
      when /save_win/
        data._accounts.data_set_hash(data)
        update_report(data._reports) +
            reply(:window_hide)
      when /up/
        accs = data._reports.accounts
        if (index = accs.index(data._accounts)) > 0
          accs[index - 1], accs[index] = accs[index], accs[index - 1]
        end
        data._reports.accounts = accs
        update_report(data._reports, data._accounts)
      when /down/
        accs = data._reports.accounts
        if (index = accs.index(data._accounts)) < accs.length - 1
          accs[index + 1], accs[index] = accs[index], accs[index + 1]
        end
        data._reports.accounts = accs
        update_report(data._reports, data._accounts)
    end
  end

  def button_report(session, name, data)
    case name
      when /add_win/
        if data._report_name.to_s.length > 0
          Reports.create(:name => data._report_name, :accounts => [])
        end
        reply(:window_hide) +
            update_reports
      when /add/
        reply(:window_show, :win_report) +
            reply(:empty, :report_name)
      when /del/
        data._reports != [] and data._reports.delete
        rpc_update(session)
    end
  end

  def rpc_button(session, name, data)
    case name
      when /^account_(.*)/
        button_account(session, $~[1], data)
      when /^report_(.*)/
        button_report(session, $~[1], data)
      when /print/
        if data._reports.class == Report
          start_thread(session, data)
          reply(:auto_update, -1) +
              reply(:update, progress_txt: 'Starting checking') +
              reply(:window_show, :progress) +
              rpc_print(session, :print, data)
        end
      when /close/
        reply(:window_hide)
      when /report_cancel/
        dputs(2){ "Killing thread #{session.s_data._report_ce_thread}"}
        if thr = session.s_data._report_ce_thread
          thr.kill
        end
        reply(:window_hide) +
            reply(:auto_update, 0)
    end
  end

  def start_thread(session, data)
    session.s_data._report_ce = nil
    session.s_data._report_ce_thread = Thread.start {
      System.rescue_all do
        session.s_data._report_ce = data._reports.print_pdf_monthly(
            Date.from_web(data._start), data._months.to_i)
      end
      dputs(2){ 'Thread finished'}
    }
  end

  def rpc_update_with_values(session, data)
    report = data._reports
    if report_ce = session.s_data._report_ce
      return reply(:window_hide) +
          reply(:auto_update, 0) +
          send_printer_reply(session, :print, data, report_ce)
    else
      return reply(:update, :progress_txt =>
                              "Accounts done: #{(report.print_accounts * 100).floor}%<br>" +
                                  "Calculating: #{report.print_account}")
    end
  end

  def rpc_list_choice_reports(session, data)
    return if data._reports == []
    reply(:empty, :accounts) +
        update_report(data._reports)
  end

  def rpc_list_choice_root(session, data)
    return if data._root == []
    update_account(data._root)
  end
end

class ComptaAdmin < View
  def layout
    @order = 300

    gui_vbox do
      gui_hbox do
        show_button :merge
      end
      gui_hbox do
        show_button :update_program
      end
      gui_hbox do
        show_button :archive, :clean_up, :connect_server
      end
      gui_window :result do
        show_html :txt
        show_button :close
      end

      gui_window :get_server do
        show_str :url, width: 200
        show_str :user
        show_str :pass
        show_button :copy_from_server
      end
    end
  end

  def rpc_update_view(session)
    super(session) +
        reply_visible(ConfigBase.has_function?(:accounting_standalone),
                      [:connect_server, :update_program])
  end

  def rpc_button_archive(session, data)
    Accounts.archive
  end

  def rpc_button_clean_up(session, data)
    count_mov, bad_mov,
        count_acc, bad_acc = AccountRoot.clean
    reply(:window_show, :result) +
        reply(:update, :txt => "Movements total / bad: #{count_mov}/#{bad_mov}<br>" +
                         "Accounts total / bad: #{count_acc}/#{bad_acc}")
  end

  def rpc_button_connect_server(session, data)
    reply(:window_show, :get_server) +
        reply(:update, url: 'http://localhost:3303/acaccess',
              user: 'other', pass: 'other')
  end

  def rpc_button_copy_from_server(session, data)
    remote = Remotes.get_db(data._url, data._user, data._pass)
    reply(:window_hide) +
        reply(:window_show, :result) +
        if remote.class == Remote
          reply(:update, txt: 'Copying was successful.')
        else
          reply(:update, txt: "Error while copying:\n#{remote}")
        end
  end

  def rpc_button_close(session, data)
    reply(:window_hide)
  end

  def rpc_button_merge(session, data)
    @merge = Thread.new do
      System.rescue_all do
        (@remote = Remotes.search_all_.first).do_merge
      end
    end
    session.s_data._compta_admin = :merge
    reply(:window_show, :result) +
        reply(:update, txt: 'Starting merge') +
        reply(:auto_update, -1)
  end

  def rpc_update_with_values(session, data)
    case session.s_data._compta_admin
      when :merge
        stat_str = %w(got_accounts put_accounts got_movements put_movements
                put_movements_changes).collect { |v| "#{v}: #{@remote.send(v)}" }.
            join('<br>')
        ret = @remote.step =~ /^done/ ? reply(:auto_update, 0) : []
        ret + reply(:update, txt: "Merge-step: #{@remote.step}<br>" + stat_str)
      when :update_program
        stat = IO.read('/tmp/update_africompta').split("\r")
        if Process.waitpid(session.s_data._update_program, Process::WNOHANG)
          reply(:update, txt: 'Update finished<br>' + stat.last(2)) +
              reply(:auto_update, 0)
        else
          reply(:update, txt: 'Updating<br>' + stat.last)
        end
      else
        dputs(0) { "Updating with #{data.inspect} and #{session.inspect}" }
    end
  end

  def rpc_button_update_program(session, data)
    session.s_data._compta_admin = :update_program
    ac_cmd = 'rsync -az --info=progress2 --bwlimit=10k profeda.org::africompta-mac ../../../..'
    session.s_data._update_program = spawn(ac_cmd, :out => '/tmp/update_africompta')

    reply(:window_show, :result) +
        reply(:update, txt: 'Starting update') +
        reply(:auto_update, -1)
  end
end
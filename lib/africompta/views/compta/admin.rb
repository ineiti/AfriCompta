class ComptaAdmin < View
  def layout
    @order = 500

    gui_hbox do
      show_button :archive, :clean_up, :connect_server, :merge
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
    super(session) + (ConfigBase.has_function?(:accounting_standalone) ?
        [] : reply(:hide, :connect_server))
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
    reply(:window_show, :result) +
        reply(:update, txt: 'Starting merge') +
        reply(:auto_update, -1)
  end

  def rpc_update_with_values(session, data)
    stat_str = %w(got_accounts put_accounts got_movements put_movements
                put_movements_changes).collect { |v| "#{v}: #{@remote.send(v)}" }.
        join('<br>')
    ret = @remote.step =~ /^done/ ? reply(:auto_update, 0) : []
    ret + reply(:update, txt: "Merge-step: #{@remote.step}<br>" + stat_str)
  end
end
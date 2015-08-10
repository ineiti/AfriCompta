class ComptaAdmin < View
  def layout
    @order = 500

    gui_hbox do
      show_button :archive, :clean_up, :connect_server
      gui_window :result do
        show_html :txt
        show_button :close
      end

      gui_window :get_server do
        show_txt :server_url
        show_button :add_server
      end
    end
  end

  def rpc_update_view(session)
    super(session) + ( ConfigBase.has_function?(:accounting_standalone) ?
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
    reply(:window_show, :get_server)
  end

  def rpc_button_add_server(session, data)

  end

  def rpc_button_close(session, data)
    reply(:window_hide)
  end
end

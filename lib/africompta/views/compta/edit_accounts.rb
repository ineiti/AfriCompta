class ComptaEditAccounts < View
  def layout
    @rpc_update = true
    @order = 100
    @functions_need = [:accounting]

    gui_hboxg do
      gui_vboxg :nogroup do
        show_entity_account :account_archive, :drop, :callback => true
        show_entity_account :account_list, :single,
                            :width => 400, :flex => 1, :callback => true
        show_button :delete, :new
      end
      gui_vbox :nogroup do
        show_str :name
        show_str :desc, :width => 300
        show_int :total
        show_button :save, :account_update
      end

      gui_window :account_new do
        show_str :name_new, :width => 300
        show_str :desc_new
        show_button :add_account, :close
      end

      gui_window :msg_win do
        show_html :msg
        show_button :close
      end
    end
  end

  def rpc_button_account_update(session, data)
    if (acc = data._account_list).class == Account
      acc.update_total
    end
  end

  def rpc_button_save(session, data)
    if (acc = data._account_list).class == Account
      acc.desc, acc.name = data._desc, data._name
      update_list
    end
  end

  def rpc_button_new(session, data)
    if data._account_list.class == Account
      reply(:window_show, :account_new) +
          reply(:empty, %w( name_new desc_new ))
    else
      reply(:window_show, :msg_win) +
          reply(:update, :msg => "Choisir un compte parent d'abord")
    end
  end

  def rpc_button_add_account(session, data)
    if (acc = data._account_list).class == Account
      return unless data._name_new.to_s.length > 0
      new_acc = Accounts.create(data._name_new, data._desc_new, acc)
      update_list(data._account_archive) +
          reply(:update, :account_list => new_acc.id) +
          reply(:window_hide)
    end
  end

  def rpc_button_delete(session, data)
    if (acc = data._account_list).class == Account
      return unless acc.is_empty
      acc.delete
      update_list(data._account_archive)
    end
  end

  def update_list(account = [])
    account.class == Account or account = AccountRoot.current

    reply(:empty_nonlists, :account_list) +
        reply(:update, :account_list => account.listp_path)
  end

  def update_archive
    reply(:empty_nonlists, :account_archive) +
        reply(:update_silent, :account_archive => [[0, "Actual"]].concat(
            if archive = AccountRoot.archive
              archive.accounts.collect { |a|
                [a.id, a.path] }.sort_by { |a| a[1] }
            else
              []
            end))
  end

  def rpc_update_view(session)
    super(session) +
        update_list +
        update_archive
  end

  def rpc_list_choice_account_list(session, data)
    reply(:empty_nonlists) +
        if (acc = data._account_list) != []
          reply(:update, {total: acc.total_form,
                          desc: acc.desc,
                          name: acc.name})
        else
          []
        end
  end

  def rpc_list_choice_account_archive(session, data)
    update_list(data._account_archive)
  end
end

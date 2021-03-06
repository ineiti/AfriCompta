class ComptaEditMovements < View

  def layout
    @rpc_update = true
    @order = 100
    @functions_need = [:accounting]

    gui_hbox do
      gui_vbox :nogroup do
        show_entity_account :account_archive, :drop, :callback => true
        show_entity_account :account_src, :drop,
                            :width => 400, :callback => true
        show_table :movement_list, :headings => [:Date, :Description, :Account, :Sub, :Total],
                   :widths => [80, 300, 200, 75, 75], :height => 400,
                   :columns => [:align_right, 0, :align_right, :align_right],
                   :callback => :edit,
                   :edit => [0, 1, 3]
        show_button :edit, :delete, :new
      end

      gui_window :movement_edit do
        show_entity_account :account_dst, :drop, :width => 400
        show_str :desc, :width => 300
        show_int :value
        show_date :date
        show_button :save, :new_mov, :close
      end
    end
  end

  def rpc_button_new_mov(session, data)
    if (acc_src = data._account_src).class == Account &&
        (acc_dst = data._account_dst).class == Account
      value = to_money(data._value)
      Movements.create(data._desc, Date.from_web(data._date), value / 1000.0,
                       acc_src, acc_dst)
      reply(:window_hide) +
          update_list(data._account_archive, data._account_src)
    end
  end

  def rpc_button_save(session, data)
    if (mov = Movements.match_by_id(data._movement_list.first._element_id)).class == Movement
      value = to_money(data._value)
      mov.desc, mov.value, mov.date =
          data._desc, value / 1000.0, Date.from_web(data._date)

      old = mov.get_other_account(data._account_src)
      dputs(3) { "Old account: #{old.get_path} - new account: #{data._account_dst.get_path}" }
      if old != data._account_dst
        mov.move_from_to(old, data._account_dst)
      end

      reply(:window_hide) +
          update_list(data._account_archive, data._account_src)
    end
  end

  def rpc_button_edit(session, data)
    if (mov = Movements.match_by_id(data._movement_list.first._element_id)).class == Movement
      other = mov.get_other_account(data._account_src).id
      reply(:window_show, :movement_edit) +
          reply(:update, :desc => mov.desc, :value => (mov.value*1000).to_i,
                :date => mov.date.to_web, :account_dst => [other]) +
          reply_show_hide(:save, :new_mov)
    end
  end

  def rpc_button_new(session, data)
    reply(:window_show, :movement_edit) +
        reply(:empty, %w( desc value )) +
        reply(:update, :date => Date.today.to_web) +
        reply_show_hide(:new_mov, :save)
  end

  def rpc_button_delete(session, data)
    if (mov = Movements.match_by_id(data._movement_list.first._element_id)).class == Movement
      mov.delete
      update_list(data._account_archive, data._account_src)
    end
  end

  def update_list(archive = nil, account = nil)
    if !(archive && account)
      return reply(:empty_nonlists, [:movement_list, :account_src]) +
          if archive
            reply(:update_silent, account_src: archive.listp_path) +
                reply(:update_silent, account_dst: archive.listp_path)
          else
            []
          end
    end

    total = account.movements.inject(0.0) { |sum, m|
      sum + (m.get_value(account) * 1000).round
    }.to_i
    reply(:empty_nonlists, :movement_list) +
        reply(:update, :movement_list => account.movements.collect { |m|
                       value = (m.get_value(account) * 1000).to_i
                       total_old = total
                       total -= value
                       other = m.get_other_account(account).get_path
                       m.date ||= Date.today
                       [m.id, [m.date.to_web, m.desc, other, value.separator,
                               total_old.separator]]
                     })
  end

  def update_accounts()
    if AccountRoot.actual
      reply(:empty_nonlists, [:account_archive, :account_src, :account_dst]) +
        reply(:update_silent, :account_archive =>
                                [[AccountRoot.actual.id, 'Actual']].concat(
                                    if archive = AccountRoot.archive
                                      archive.accounts.collect { |a|
                                        [a.id, a.path] }.sort_by { |a| a[1] }
                                    else
                                      []
                                    end)) +
        update_list(AccountRoot.actual, AccountRoot.actual) +
        reply(:update, :account_src => AccountRoot.actual.listp_path,
              :account_dst => AccountRoot.actual.listp_path)
    end
  end

  def rpc_update_view(session)
    super(session) +
        update_list +
        update_accounts
  end

  def rpc_update(session)
    reply(:update, :date => Date.today.to_web)
  end

  def rpc_list_choice_account_src(session, data)
    return if data._account_src == []
    update_list(data._account_archive, data._account_src)
  end

  def rpc_list_choice_account_archive(session, data)
    return if data._account_archive == []
    update_list(data._account_archive)
  end

  def rpc_list_choice_movement_list(session, data)
    if (mov = data._movement_list).class == Movement
      reply(:update, :desc => mov.desc, :value => (mov.value * 1000).to_i,
            :date => mov.date.to_web)
    end
  end

  def rpc_table_movement_list(session, data)
    ml = data._movement_list.first
    dst = Accounts.get_by_path(ml._Account)
    rpc_button_save(session, data.merge('value' => ml._Sub, 'desc' => ml._Description,
                           'date' => ml._Date, 'account_dst' => dst))
    #if (mov = Movements.match_by_id(data._movement_list.first)).class == Movement
    #  rpc_button_edit(session, data)
    #end
  end

  # Delete all non-number characters, but also accept european
  # 10,5 == 10.5
  def to_money(str)
    return str.delete('^0123456789.,-').gsub(/,/, '.').to_f
  end
end

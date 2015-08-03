class ComptaDefaults < View
  def layout
    @order = 300
    @update = true
    set_data_class(:ConfigBases)
    @functions_need = [:accounting]

    gui_vbox do
      gui_hboxg :nogroup do
        show_block :accounts
        show_arg :account_cash, :width => 400
      end
      show_button :save
    end
  end

  def rpc_update(session)
    accounts_current = []
    AccountRoot.current.get_tree_depth { |a|
      accounts_current.push [a.id, a.get_path]
    }
    reply(:empty_nonlists) +
        reply(:update, ConfigBases.get_block_fields(:accounts).collect { |acc|
                       [acc, accounts_current]
                     }.to_h) +
        update_form_data(ConfigBases.singleton)

  end

  def rpc_button_save(session, data)
    ConfigBase.store(data.to_sym)
    dputs(3) { "Configuration is now #{ConfigBase.get_functions.inspect}" }

    rpc_update(session)
  end
end
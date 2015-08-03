

class ComptaAdmin < View
  def layout
    @order = 40
		
    gui_hbox do
      show_button :archive, :update_totals, :clean_up
      gui_window :result do
        show_html :txt
        show_button :close
      end
    end
  end
	
  def rpc_button_archive( session, data )
    Accounts.archive
  end
	
  def rpc_button_update_totals( session, data )
    if session.owner.account_due
      session.owner.account_due.update_total
    end
  end
  
  def rpc_button_clean_up( session, data )
    count_mov, bad_mov, 
      count_acc, bad_acc = AccountRoot.clean
    reply( :window_show, :result ) +
      reply( :update, :txt => "Movements total / bad: #{count_mov}/#{bad_mov}<br>" +
        "Accounts total / bad: #{count_acc}/#{bad_acc}")
  end
  
  def rpc_button_close( session, data )
    reply( :window_hide )
  end
end

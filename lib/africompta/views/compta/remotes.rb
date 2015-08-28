class ComptaRemotes < View
  include VTListPane
  def layout
    @order = 500
    
    set_data_class :Remotes

    gui_hbox do
      gui_vbox :nogroup do
        vtlp_list :remotes_list, 'url', width: 250, maxheight: 250
        show_button :new
      end
      gui_vbox :nogroup do
        show_str :url, width: 250
        show_str :name
        show_str :pass
        show_int :account_index
        show_int :movement_index
        show_button :save
      end
    end
  end
end

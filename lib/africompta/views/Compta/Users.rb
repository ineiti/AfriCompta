class ComptaUsers < View
  include VTListPane
  def layout
    @order = 20
    
    set_data_class :Users

    gui_hbox do
      gui_vbox :nogroup do
        vtlp_list :users_list, 'name', :width => 150, :maxheight => 250
        show_button :new
      end
      gui_vbox :nogroup do
        show_str :name
        show_str :full
        show_str :pass
        show_int :account_index
        show_int :movement_index
        show_button :save
      end
    end
  end
end

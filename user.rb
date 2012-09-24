module Compta::Models
  class User < Base;
    has_and_belongs_to_many :accounts;
    
    def set( name, full, pass, accounts )
      self.name, self.full, self.pass = name, full, pass;
      self.accounts.clear
      accounts.each { |a|
        self.accounts << Account.find_by_id( a )
      }
      if not self.movement_index or not self.account_index
        self.movement_index = self.account_index = 0
      end
    end
    
    def update_movement_index
      self.movement_index = User.find_by_name('local').movement_index - 1
      save
    end
    
    def update_account_index
      self.account_index = User.find_by_name('local').account_index - 1
      save
    end
    
    def to_s
      "#{full},#{name}"
    end
    
    def User.create_v01( name, full, pass )
      u = User.new( :name => name, :full => full, :pass => pass )
      u.save
    end
    def User.create( name, full, pass )
      u = User.new( :name => name, :full => full, :pass => pass )
      u.movement_index = u.account_index = 0
      u.save
    end
    
    def User.find_all
      users = find( :all )
      users.delete_if{ |u| 
        u.name == "local"
      }
    end
    
  end
end    


module Compta::Controllers
  #
  # USER-related stuff
  #
  class UserClasses < R '/user/(.*)'
    def fillGlobal
      @accounts = Account.find :all
      @accounts_root = Account.find_all_by_account_id( 0 )
      @users = User.find( :all )
    end
    def get( p )
      fillGlobal
      path, arg = p.split("/")
      case path
        when "list"
        render :user_list
        when "add"
        @user = User.new( :name => "Username", :full => "Full name", :pass => "fadjal" )
        render :user_edit
        when "delete"
        User.destroy( arg )
        fillGlobal
        render :user_list        
        when "edit"
        @user = User.find_by_id( arg )
        render :user_edit
        when "copied"
        @user = User.find_by_id( arg )
        @user.update_account_index
        @user.update_movement_index
        render :user_copied
      end
    end
    def post( p )
      path, arg = p.split("/")
      case path
        when "edit"
        u = User.find_or_initialize_by_id( input.uid )
        u.set( input.name, input.full, input.pass, input.accounts.to_a )
        u.save
        fillGlobal
        render :user_list
      end
    end
  end
end


module Compta::Views
  #
  # User
  #
  def user_list
    h1 "Users active:"
    table do
      @users.to_a.each{ |u|
        tr do 
          td.small { a "Edit", :href => "/user/edit/" + u.id.to_s }
          td.small { a "Copied", :href => "/user/copied/" + u.id.to_s }
          td.small { a "Delete", :href => "/user/delete/" + u.id.to_s }
          td {
            pre u.name
          }
        end
      }
    end
    p { 
      a "Add user", :href=> "/user/add"
    text( "-" )
      a "Home", :href=>"/"
    }
  end
  
  def user_copied
    h1 "User copied"
    p "Just copied user #{@user.name}"
    ["movement_index","account_index"].each{ |ind| 
      tr{
        td ind
        td { @user[ind].to_s }
      }
    }
    p { 
      a "Add user", :href=> "/user/add"
    text( "-" )
      a "Home", :href=>"/"
    }
  end
  
  def user_edit
    form :action => "/user/edit", :method => 'post' do
      table do
        [["User name", "name"], ["Full name", "full"], ["Password", "pass"]].each{|p|
          tr{ 
            td p[0]
            td { input :type => 'text', :name => p[1], :value => @user[p[1]] }
          }
        }
        tr{
          td "Accounts"
          td {
            select :name => "accounts", :size => "10", :multiple => "" do
              list_sub( @accounts_root.to_a ){ |acc, str|
                if @user.accounts.find_by_id( acc.id )
                  option str, :value => acc.id, :selected => ""
                else
                  option str, :value => acc.id
                end
              }
            end
          }
        }
        ["movement_index","account_index"].each{ |ind| 
          tr{
            td ind
            td { @user[ind].to_s }
          }
        }
      end
      input :type => 'hidden', :name => "uid", :value => @user.id
      input :type => 'submit', :value => @user.new_record? ? "Add user" : "Save changes"
    end
  end
end

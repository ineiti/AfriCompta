module Compta::Models
  # An account is like a cash-pot. It can represent as well a
  # physical resource (purse, bank account) or an abstract
  # meaning (expenses, incomes)
  #  Accounts are stored in a hierarchical way, so there are sub-accounts
  # and more. The top-account has an +:account_id+ of +null+
  class Account < Base;
    include Performance
    
    has_many :movements_src, :foreign_key => "account_src_id", :class_name => "Movement";
    has_many :movements_dst, :foreign_key => "account_dst_id", :class_name => "Movement";
    has_many :accounts;
    belongs_to :account;
    has_and_belongs_to_many :users;
    attr :subsum, true
    
    # This gets the tree under that account, breadth-first
    def get_tree
      yield self
      accounts.each{|a|
        a.get_tree{|b| yield b} 
      }
    end
    
    def path( sep = "::", p="", first=true )
      if self.account
        return self.account.path( sep, p, false ) + self.name + ( first ? "" : sep )
      else
        return self.name + sep
      end
    end
    
    def new_index()
      u_l = User.find_by_name('local')
      self.index = u_l.account_index
      u_l.account_index += 1
      u_l.save
      debug 0, "Index for account #{name} is #{index}"
    end
    
    # Sets different new parameters.
    def set_nochildmult( name, desc, parent, multiplier = 1, users = [] )
      if self.new_record?
        debug 4, "New record in nochildmult"
        self.total = 0
        # We need to save so that we have an id...
        save
        self.global_id = User.find_by_name('local').full + "-" + self.id.to_s
      end
      self.name, self.desc, self.account_id = name, desc, parent.to_i;
      self.users.clear
      users.each { |u|
        self.users << User.find_by_name( u )
      }
      self.multiplier = multiplier
      # And recalculate everything.
      # TODO - why start with -10?
      total = -10
      movements.each{|m|
        total += m.getValue( self )
      }
      new_index
      save
    end
    def set( name, desc, parent, multiplier = 1, users = [] )
      debug 1, "Setting #{name}"
      set_nochildmult( name, desc, parent, multiplier, users )
      # All descendants shall have the same multiplier
      set_child_multipliers( multiplier )
      save
    end
    
    # Sort first regarding inverse date (newest first), then description, 
    # and finally the value
    def movements( from = nil, to = nil )
      debug 5, "Account::movements"
      timer_start
      movs = ( movements_src + movements_dst )
      if ( from != nil and to != nil )
        movs.delete_if{ |m|
          ( m.date < from or m.date > to )
        }
        debug 3, "Rejected some elements"
      end
      timer_read("rejected elements")
      sorted = movs.sort{ |a,b|
        ret = 0
        if a.date and b.date
          ret = -( a.date <=> b.date )
        end
        if ret == 0
          if a.desc and b.desc
            ret = a.desc <=> b.desc
          end
          if ret == 0
            if a.value and b.value
              ret = a.value.to_f <=> b.value.to_f
            end
          end
        end
        ret
      }
      timer_read( "Sorting movements: " )
      sorted
    end
    
    def Account.create( name, desc, parent, global_id )
      parent = parent.to_i
      a = Account.new( :name => name, :desc => desc, :account_id => parent,
        :global_id => global_id.to_s )
      a.total = "0"
      # TODO: u_l.save?
      if parent > 0
        a.multiplier = Account.find_by_id( parent ).multiplier
      else
        a.multiplier = 1
      end
      a.new_index
      a.save
      a
      debug 2, "Created account #{a.name}"
    end
    
    def to_s( add_path = false )
      if account || true
        "Account-desc: #{name.to_s}, #{global_id}"
        "#{desc}\r#{global_id}\t" + 
          "#{total.to_s}\t#{name.to_s}\t#{multiplier.to_s}\t" +
          ( (account_id and account_id > 0 ) ? account.global_id.to_s : "" ) +
          "\t#{deleted.to_s}" + ( add_path ? "\t#{path}" : "" )
      else
        "nope"
      end
    end
    
    def is_empty
      size = self.movements.select{|m| m.value.to_f != 0.0 }.size
      debug 2, "Account #{self.name} has #{size} non-zero elements"
      if size == 0 and self.accounts.size == 0
        return true
      end
      return false
    end
    
    def delete
      if self.is_empty
        debug 2, "Deleting account #{self.name} with #{self.deleted.inspect}"
        self.deleted = true
        self.new_index
        self.save
        debug 2, "account #{self.name} is now #{self.deleted.inspect}"
      end
    end
    
    # Gets an account from a string, if it doesn't exist yet, creates it.
    # It will update it anyway.
    def Account.from_s( str )
      desc, str = str.split("\r")
      if not str
        debug 0, "Invalid account found: #{desc}"
        return [ -1, nil ]
      end
      global_id, total, name, multiplier, par, deleted = str.split("\t")
      total, multiplier = total.to_f, multiplier.to_f
      debug 3, "Here comes the account: " + global_id.to_s
      debug 5, "par: #{par}"
      if par
        parent = Account.find_by_global_id( par )
        debug 5, "parent: #{parent.global_id}"
      end
      debug 3, "global_id: #{global_id}"
      # Does the account already exist?
      our_a = nil
      if not ( our_a = Account.find_by_global_id(global_id) )
        # Create it
        our_a = Account.new
      end
      # And update it
      pid = par ? parent.id : 0
      our_a.deleted = deleted
      our_a.set_nochildmult( name, desc, pid, multiplier )
      our_a.global_id = global_id
      our_a.save
      debug 2, "Saved account #{name} with index #{our_a.index} and global_id #{our_a.global_id}"
      return our_a
    end
    
    # Be sure that all descendants have the same multiplier
    def set_child_multipliers( m )
      debug 3, "Setting multiplier from #{name} to #{m}"
      self.multiplier = m
      save
      return if not accounts
      accounts.each{ |acc|
        acc.set_child_multipliers( m )
      }
    end
    
    def self.find_not_deleted
      Account.find( :all ).select{|a|
        debug 2, "Account #{a.name} is #{a.deleted.inspect}"
        not a.deleted
      }
    end
  end
end  


module Compta::Controllers
  #
  # Everything related to ACCOUNTS
  #
  class AccountClasses < R '/account/(.*)'
    def fillGlobal
      @accounts = Account.find_not_deleted
      @accounts_root = @accounts.select{|a|
        debug 0, "#{a.name} - #{a.account_id} - #{a.deleted}"
        not a.account 
      }
      @users = User.find_all
    end
    def get( p )
      fillGlobal
      path, arg = p.split("/")
      debug 1, path + "<->" + arg.to_s
      case path
      when "add"
        parent = Account.find_by_id( arg.to_i )
        if not parent
          parent = Account.new( :multiplier => 1 )
        end
        @account = Account.new( :name => "Short name", :desc => "Full description", 
          :account => parent, :multiplier => parent.multiplier )
        render :account_edit
      when "edit"
        @account = Account.find_by_id( arg )
        debug 2, "Account is #{@account.to_s}"
        render :account_edit
      when "delete"
        if Account.find_by_id( arg ).delete
          @account_deleted = true
        else
          @account_deleted = false
        end
        fillGlobal
        render :account_list
      when "list"
        fillGlobal
        render :account_list
      end
    end
    
    def post( p )
      fillGlobal
      path, arg = p.split("/")
      debug 1, path + "<->" + arg.to_s
      case path
      when "edit"
        a = Account.find_or_initialize_by_id( input.aid )
        a.set( input.name, input.desc, input.parent, input.multiplier, input.users.to_a )
        a.save
        debug 2, "Edited account: #{a.to_s}"
        debug 2, "Accounts here: #{Account.find(:all).size}"
        fillGlobal
        debug 2, "Accounts here: #{Account.find(:all).size}"
        render :account_list
      end
    end
  end
end  


module Compta::Views
  #
  # Accounts
  #  
  def account_list
    a "Home", :href => "/"
    b "-"
    a "Add account", :href=> "/account/add"
    h1 "Available accounts:"
    table do
      list_sub( @accounts_root.to_a ){ |acc, str|
        tr do 
          td.small { a "Edit", :href => "/account/edit/" + acc.id.to_s }
          td.small {
            if acc.is_empty
              a "Delete", :href => "/account/delete/" + acc.id.to_s
            else
              "NE"
            end
          }
          td.small { a "Add", :href => "/account/add/" + acc.id.to_s }
          td {
            pre str
          }
        end
      }
    end
    a "Home", :href => "/"
    b "-"
    a "Add account", :href=> "/account/add"
  end
  
  def account_edit
    form :action => "/account/edit", :method => 'post' do
      table do
        tr{ 
          td "Account name"
          td { input :type => 'text', :name => "name", :value => @account.name }
        }
        tr{
          td "Description"
          td { input :type => 'text', :name => "desc", :value => @account.desc }
        }
        tr {
          td "Multiplier"
          td { 
            select :name => "multiplier", :size => "1" do
              [ 1, -1 ].each{ |v| 
                if @account.multiplier == v
                  option v, :value => v, :selected => ""
                else
                  option v, :value => v
                end
              }
            end
          }
        }
        tr{
          td "Top-Account"
          td { 
            select :name => "parent", :size => "1" do
              option "Top-account", :value => "0"
              list_sub( @accounts_root.to_a ){ |acc, str|
                if acc == @account.account
                  option str, :value => acc.id, :selected => ""
                elsif acc.id != @account.id
                  option str, :value => acc.id
                end
              }
            end
          }
        }
        tr {
          td "Users"
          td {
            select :name => "users", :size => "5", :multiple => "" do
              @users.each{ |u|
                if @account.users.find_by_name( u.name )
                  option u.name, :selected => ""
                else
                  option u.name
                end
              }
            end
          }
        }
        ["id","global_id","account_id"].each{ |ind| 
          tr{
            td ind
            td { @account[ind].to_s }
          }
        }
      end
      input :type => 'hidden', :name => "aid", :value => @account.id
      input :type => 'submit', :value => @account.new_record? ? "Add account" : "Save changes"
    end
  end
end

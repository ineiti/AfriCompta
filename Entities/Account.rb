class AccountRoot
  def self.accounts
    Accounts.matches_by_account_id( 0 )
  end
  
  def self.clean
    count_mov, count_acc = 0, 0
    bad_mov, bad_acc = 0, 0
    Movements.search_all.each{ |m|
      dputs(4){"Testing movement #{m.inspect}"}
      if not m or not m.date or not m.desc or not m.value or 
          not m.index or not m.account_src or not m.account_dst
        if m and m.desc
          dputs(1){ "Bad movement: #{m.desc}" }
        end
        m.delete
        bad_mov += 1
      end
      if m.index
        count_mov = [ count_mov, m.index ].max
      end
    }
    Accounts.search_all.each{ |a|
      if ( a.account_id and a.account_id > 0 ) and not a.account
        a.delete
        bad_acc += 1
      end
      count_acc = [ count_acc, a.index ].max
    }

    # Check also whether our counters are OK
    u_l = Users.match_by_name('local')
    dputs(1){ "Movements-index: #{count_mov} - #{u_l.movement_index}" }
    dputs(1){ "Accounts-index: #{count_acc} - #{u_l.account_index}" }
    @ul_mov, @ul_acc = u_l.movement_index, u_l.account_index
    if count_mov > u_l.movement_index
      dputs(0){ "Error, there is a bigger movement! Fixing" }
      u_l.movement_index = count_mov + 1
      u_l.save
    end
    if count_acc > u_l.account_index
      dputs(0){ "Error, there is a bigger account! Fixing" }
      u_l.account_index = count_acc + 1
      u_l.save
    end
    return [ count_mov, bad_mov, count_acc, bad_acc ]
  end
end

class Accounts < Entities
  def setup_data
    @default_type = :SQLiteAC
    @data_field_id = :id
    
    value_str :name
    value_str :desc
    value_str :global_id
    value_float :total
    value_int :multiplier
    value_int :index
    value_entity_account :account_id
  end
    
  def self.create( name, desc = "Too lazy", parent = nil, global_id = "" )
    if parent
      if parent.class != Account
        parent = Accounts.matches_by_index( parent ).first
      end
      a = super( :name => name, :desc => desc, :account_id => parent.id,
        :global_id => global_id.to_s, :multiplier => parent.multiplier )
    else
      a = super( :name => name, :desc => desc, :account_id => 0,
        :global_id => global_id.to_s, :multiplier => 1 )
    end
    a.total = "0"
    a.new_index
    if global_id == ""
      a.global_id = Users.find_by_name('local').full + "-" + a.id.to_s
    end
    a.save
    ddputs( 2 ){ "Created account #{a.path_id}" }
    a
  end
	
  def self.create_path( path, desc, double_last = false, mult = 1 )
    elements = path.split( "::" )
    last_id = nil
    elements.each{|e|
      dputs( 5 ){ "Working on element #{e}" }
      if ( e == elements.last ) and double_last
        dputs( 3 ){ "Doubling account #{path}" }
        last_id = Accounts.create( e, desc, last_id )
      else
        t = Accounts.matches_by_name( e ).select{|a|
          dputs( 5 ){ "Account_id is #{a.account_id}" }
          if a.account_id == last_id
            last_id = a
          end
        }
        if t == []
          last_id = Accounts.create( e, desc, last_id )
        end
      end
    }
    last_id.set_child_multipliers( mult )
    last_id
  end

  # Gets an account from a string, if it doesn't exist yet, creates it.
  # It will update it anyway.
  def self.from_s( str )
    desc, str = str.split("\r")
    if not str
      dputs( 0 ){ "Invalid account found: #{desc}" }
      return [ -1, nil ]
    end
    global_id, total, name, multiplier, par = str.split("\t")
    total, multiplier = total.to_f, multiplier.to_f
    dputs( 3 ){ "Here comes the account: " + global_id.to_s }
    dputs( 5 ){ "par: #{par}" }
    if par
      parent = Accounts.find_by_global_id( par )
      dputs( 5 ){ "parent: #{parent.global_id}" }
    end
    dputs( 3 ){ "global_id: #{global_id}" }
    # Does the account already exist?
    our_a = nil
    pid = par ? parent.id : 0
    if not ( our_a = Accounts.find_by_global_id(global_id) )
      # Create it
      our_a = Accounts.create( name, desc, Accounts.find_by_id( par ), global_id )
    end
    # And update it
    our_a.set_nochildmult( name, desc, pid, multiplier )
    our_a.global_id = global_id
    our_a.save
    dputs( 2 ){ "Saved account #{name} with index #{our_a.index} and global_id #{our_a.global_id}" }
    return our_a
  end
	
  def self.get_by_path( parent, elements = nil )
    if not elements
      if parent
        return get_by_path( AccountRoot, parent.split("::") )			
      else
        return nil
      end
    end
		
    child = elements.shift
    parent.accounts.each{|a|
      if a.name == child
        if elements.length > 0
          return get_by_path( a, elements )
        else
          return a
        end
      end
    }
    return nil
  end
	
  def self.get_id_by_path( p )
    if a = get_by_path( p )
      return a.id.to_s
    else
      return nil
    end
  end
	
  def archive_parent( acc, years_archived, year )
    dputs( 3 ){ "years_archived is #{years_archived.inspect}" }
    if not years_archived.has_key? year
      dputs( 2 ){ "Adding #{year}" }
      years_archived[year] = 
        Accounts.create_path( "Archive::#{year}", "New archive" )
    end
    # This means we're more than one level below root, so we can't
    # just copy easily
    if acc.path.split('::').count > 2
      return Accounts.create_path( "Archive::#{year}::"+
          "#{acc.parent.path.gsub(/^Root::/,'')}", "New archive", false,
        acc.multiplier )
    else
      return years_archived[year]
    end
  end
		
  def search_account( acc, month_start )
    years = Hash.new(0)
    acc.movements.each{|mov|
      y, m, d = mov.date.to_s.split("-").collect{|d| d.to_i}
      dputs( 5 ){ "Date of #{mov.desc} is #{mov.date}" }
      m < month_start and y -= 1
      years[y] += 1
    }
    dputs( 3 ){ "years is #{years.inspect}" }
    years
  end
		
  def create_accounts( acc, years, years_archived, this_year )
    years.keys.each{|y|
      if y == this_year
        dputs(3){"Creating path #{acc.path}"}
        years[y] = Accounts.create_path( acc.path, acc.desc, 
          true, acc.multiplier )
      else
        path = "#{archive_parent( acc, years_archived, y ).path}::" +
          acc.name
        dputs(3){"Creating other path #{path}"}
        years[y] = Accounts.create_path( path, acc.desc, false,
          acc.multiplier )
      end
      dputs( 3 ){ "years[y] is #{years[y].path_id}" }
    }
  end
		
  def move_movements( acc, years, month_start )
    acc.movements.each{|mov|
      dputs( 5 ){ "Start of each" }
      y, m, d = mov.date.to_s.split("-").collect{|d| d.to_i}
      dputs( 5 ){ "Date of #{mov.desc} is #{mov.date}" }
      m < month_start and y -= 1
      if years.has_key? y
        dputs( 5 ){ "Moving to #{years[y].inspect}: " +
            "#{mov.account_src.id} - #{mov.account_dst.id} - #{acc.id}" }
        if mov.account_src.id == acc.id
          dputs( 5 ){ "Moving src" }
          mov.account_src_id = years[y]
        else
          dputs( 5 ){ "Moving dst" }
          mov.account_dst_id = years[y]
        end
        dputs( 5 ){ "new_index" }
        mov.new_index
        dputs( 5 ){ "new_index finished" }
      end
    }
    dputs( 5 ){ "Movements left in account #{acc.path}:" }
    acc.movements.each{|m|
      dputs( 5 ){ m.desc }
    }
  end
		
  def sum_up_total( acc_path, years_archived, month_start )
    a_path = acc_path.sub( /[^:]*::/, '' )
    dputs( 3 ){ "Summing up account #{a_path}" }
    acc_sum = []
    years_archived.each{|y, a|
      dputs( 5 ){ "Found archived year #{y.inspect} which is #{y.class.name}" }
      aacc = Accounts.get_by_path( a.get_path + "::" + a_path )
      acc_sum.push [y, a, aacc]
    }
    dputs( 5 ){ "Trying to add current year" }
    if curr_acc = Accounts.get_by_path( acc_path )
      dputs( 4 ){ "Adding current year" }
      acc_sum.push [9999, nil, curr_acc ]
    end

    last_total = 0
    last_year_acc = nil
    last_year = 0
    dputs( 5 ){ "Sorting account_sum of length #{acc_sum.length}" }
    acc_sum.sort{|a,b| a[0] <=> b[0]}.each{|y, a, aacc|
      dputs( 5 ){ "y, a, aacc: #{y}, #{a}, #{aacc.to_s}" }
      if aacc
        dputs( 4 ){ "Found archived account #{aacc.get_path} for year #{y}" }
        dputs( 5 ){ "And has movements" }
        aacc.movements.each{|m|
          dputs( 5 ){ m.to_json }
        }
        if last_total != 0
          dputs( 3 ){ "Creating movement for the sum of last year: #{last_total}" }
          mov = Movements.create( "Sum of #{last_year}", 
            "#{last_year}-#{month_start}-01", last_total, last_year_acc, aacc )
          dputs( 3 ){ "Movement is: #{mov.to_json}" }
        end
        aacc.update_total
        dputs( 5 ){ "#{aacc.total.class.name} - #{aacc.multiplier.class.name}" }
        last_total = aacc.total * aacc.multiplier
      else
        dputs( 4 ){ "Didn't find archived account for #{y}" }
        last_total = 0
      end
      last_year, last_year_acc = y, a
    }
  end

  def self.archive( month_start = 1, this_year = nil, only_account = nil )		
    if not this_year
      this_year = Time.now.year
      Time.now.month < month_start and this_year -= 1
    end
		
    root = self.find_by_name( 'Root' )
    if only_account
      root = only_account
    else
      if root.account_id
        dputs( 0 ){ "Can't archive with Root is not in root: #{root.account_id.inspect}!" }
      end
    end
		
    archive = self.find_by_name( 'Archive' )
    if not archive
      archive = self.create( 'Archive' )
    end
		
    years_archived = {}
    archive.accounts.each{|a| years_archived[a.name.to_i] = a }
		
    dputs( 2 ){ "Got root and archive" }
    # For every account we search the most-used year, so
    # that we can move the account to that archive. This way
    # we omit as many as possible updates for the clients, as
    # every displacement of a movement will have to be updated,
    # while the displacement of an account is much simpler
    root.get_tree_depth{|acc|
      dputs( 2 ){ "Looking at account #{acc.path}" }
      years = search_account( acc, month_start )

      if years.size > 0
        most_used = last_used = this_year
        if acc.accounts.count == 0
          most_used = years.index( years.values.max )
          last_used = years.keys.max
          years.delete most_used
        end
        acc_path = acc.path
				
        dputs( 3 ){ "most_used: #{most_used} - last_used: #{last_used}" +
            "- acc_path: #{acc_path}" }

        # First move all other movements around
        if years.keys.size > 0
          create_accounts( acc, years, years_archived, this_year )
					
          move_movements( acc, years, month_start )
        end

        if most_used != this_year
          # Now move account to archive-year of most movements
          parent = archive_parent( acc, years_archived, most_used )
          if double = Accounts.get_by_path( "#{parent.get_path}::#{acc.name}" )
            ddputs(3){"Account #{acc.path_id} already exists in #{parent.path_id}"}
            # Move all movements
            acc.movements.each{|m|
              ddputs(4){"Moving movement #{m.to_json}"}
              if m.account_src == acc
                m.account_src_id = double
              else
                m.account_dst_id = double
              end
            }
            # Delete acc
            acc.delete
          else
            ddputs( 3 ){ "Moving account #{acc.path_id} to #{parent.path_id}" }
            acc.parent = parent
            acc.new_index
          end
        end

        # Check whether we need to add the account to the current year
        if ( last_used >= this_year - 1 ) and 
            ( most_used != this_year )
          dputs( 3 ){ "Adding #{acc_path} to this year" }
          Accounts.create_path( acc_path, "Copied from archive", false,
            acc.multiplier )
        end
				
        # And create a trail so that every year contains the previous
        # years worth of "total"
        sum_up_total( acc_path, years_archived, month_start )
        dputs( 5 ){ "acc_path is now #{acc_path}" }
      else
        dputs( 3 ){ "Empty account" }
      end
    }
    ddputs( 3 ){ "Root-tree is now" }
    root.get_tree_depth{|a|
      ddputs( 3 ){ a.path_id }
      a.movements.each{|m|
        ddputs(4){"Movement is #{m.inspect}"}
      }
    }
    ddputs( 3 ){ "Archive-tree is now" }
    archive.get_tree_depth{|a|
      ddputs( 3 ){ a.path_id }
      a.movements.each{|m|
        ddputs(4){"Movement is #{m.to_json}"}
      }
    }
  end
end

class Account < Entity

  # This gets the tree under that account, breadth-first
  def get_tree
    yield self
    accounts.each{|a|
      a.get_tree{|b| yield b} 
    }
  end
    
  # This gets the tree under that account, depth-first
  def get_tree_depth
    accounts.each{|a|
      a.get_tree_depth{|b| yield b} 
    }
    yield self
  end
    
  def get_tree_debug( ind = "" )
    yield self
    dputs( 0 ){ "get_tree_ #{ind}#{self.name}" }
    accounts.each{|a|
      a.get_tree_debug( "#{ind} " ){|b| yield b} 
    }
  end
    
  def path( sep = "::", p="", first=true )
    if self.account
      return self.account.path( sep, p, false ) + sep + self.name
    else
      return self.name
    end
  end
	
  def path_id( sep = "::", p="", first=true )
    ( self.account ? 
        "#{self.account.path_id( sep, p, false )}#{sep}" : "" ) +
      "#{self.name}-#{self.id}"
  end
	
  def get_path( sep = "::", p = "", first = true )
    path( sep, p, first )
  end
    
  def new_index()
    u_l = Users.find_by_name('local')
    self.index = u_l.account_index
    u_l.account_index += 1
    u_l.save
    dputs( 3 ){ "Index for account #{name} is #{index}" }
  end
	
  def update_total( precision = 3 )
    # Recalculate everything.
    dputs( 4 ){ "Calculating total for #{self.path_id} with mult #{self.multiplier}" }
    self.total = ( 0.0 ).to_f
    dputs( 4 ){ "Final total is #{self.total} - #{self.total.class.name}" }
    self.movements.each{|m|
      dputs( 5 ){ "Adding value #{m.get_value( self )}" }
      v = m.get_value( self )
      dputs( 5 ){ "Value is #{v.inspect}" }
      self.total = self.total.to_f + v.to_f
    }
    self.total = self.total.round( precision )
    dputs( 4 ){ "Final total is #{self.total} - #{self.total.class.name}" }
  end

  # Sets different new parameters.
  def set_nochildmult( name, desc, parent, multiplier = 1, users = [] )
    if self.new_record?
      dputs( 4 ){ "New record in nochildmult" }
      self.total = 0
      # We need to save so that we have an id...
      save
      self.global_id = User.find_by_name('local').full + "-" + self.id.to_s
    end
    self.name, self.desc, self.account_id = name, desc, parent;
    # TODO: implement link between user-table and account-table
    # self.users = users ? users.join(":") : ""
    self.multiplier = multiplier
    update_total
    new_index
    save
  end
  def set( name, desc, parent, multiplier = 1, users = [] )
    set_nochildmult( name, desc, parent, multiplier, users )
    # All descendants shall have the same multiplier
    set_child_multipliers( multiplier )
    save
  end
    
  # Sort first regarding inverse date (newest first), then description, 
  # and finally the value
  def movements( from = nil, to = nil )
    dputs( 5 ){ "Account::movements" }
    timer_start
    movs = ( movements_src + movements_dst )
    if ( from != nil and to != nil )
      movs.delete_if{ |m|
        ( m.date < from or m.date > to )
      }
      dputs( 3 ){ "Rejected some elements" }
    end
    timer_read("rejected elements")
    sorted = movs.sort{ |a,b|
      ret = 0
      if a.date and b.date
        ret = a.date.to_s <=> b.date.to_s
      end
      if ret == 0
        ret = a.index <=> b.index
=begin        
        if a.desc and b.desc
          ret = a.desc <=> b.desc
        end
        if ret == 0
          if a.value and b.value
            ret = a.value.to_f <=> b.value.to_f
          end
        end
=end
      end
      ret * -1
    }
    timer_read( "Sorting movements: " )
    sorted
  end
	    
  def to_s( add_path = false )
    if account || true
      "Account-desc: #{name.to_s}, #{global_id}"
      "#{desc}\r#{global_id}\t" + 
        "#{total.to_s}\t#{name.to_s}\t#{multiplier.to_s}\t" +
        ( account_id ? account.global_id.to_s : "" ) +
        ( add_path ? "\t#{path}" : "" )
    else
      "nope"
    end
  end
    
  def is_empty
    size = self.movements.select{|m| m.value.to_f != 0.0 }.size
    dputs( 2 ){ "Account #{self.name} has #{size} non-zero elements" }
    if size == 0 and self.accounts.size == 0
      return true
    end
    return false
  end
    
  # Be sure that all descendants have the same multiplier
  def set_child_multipliers( m )
    dputs( 3 ){ "Setting multiplier from #{name} to #{m}" }
    self.multiplier = m
    save
    return if not accounts
    accounts.each{ |acc|
      acc.set_child_multipliers( m )
    }
  end
	
  def accounts
    Accounts.matches_by_account_id( self.id )
  end
	
  # This is the parent account
  def account
    account_id
  end
	
  def account= ( a )
    self.account_id = a
  end
	
  def parent
    account
  end
	
  def parent= ( a )
    self.account_id = a
  end
	
  def movements_src
    Movements.matches_by_account_src_id( self.id )
  end
	
  def movements_dst
    Movements.matches_by_account_dst_id( self.id )
  end
end

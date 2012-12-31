require 'test/unit'

class TC_AfriCompta < Test::Unit::TestCase
  def setup
    #    delete_all_data()
    #    Persons.create( :first_name => "admin", :password => "super123", :permissions => [ "admin" ] )
    #    Persons.create( :first_name => "josue", :password => "super", :permissions => [ "secretary" ] )
    #    Persons.create( :first_name => "surf", :password => "super", :permissions => [ "internet" ] )
    FileUtils.cp( "db.testGestion", "data/compta.db" )
    Entities.Movements.load
    Entities.Accounts.load
    Entities.Users.load
    @root = Accounts.find_by_name( "Root" )
    @cash = Accounts.find_by_name( "Cash" )
    @income = Accounts.find_by_name( "Income" )
    @outcome = Accounts.find_by_name( "Outcome" )
    @local = Users.find_by_name( 'local' )
  end

  def teardown
  end

  def test_db
    movs = Movements.search_all
    assert_equal 4, movs.length
    accs = Accounts.search_all
    assert_equal 5, accs.length
    users = Users.search_all
    assert_equal 2, users.length
		
    assert_equal [{:id=>1,
        :value=>1000.0,
        :desc=>"Salary",
        :revision=>nil,
        :account_src_id=>[2],
        :global_id=>"5544436cf81115c6faf577a7e2307e92-1",
        :index=>1,
        :account_dst_id=>[3]},
      {:id=>2,
        :value=>100.0,
        :desc=>"Gift",
        :revision=>nil,
        :account_src_id=>[2],
        :global_id=>"5544436cf81115c6faf577a7e2307e92-2",
        :index=>2,
        :account_dst_id=>[3]},
      {:id=>3,
        :value=>40.0,
        :desc=>"Train",
        :revision=>nil,
        :account_src_id=>[4],
        :global_id=>"5544436cf81115c6faf577a7e2307e92-3",
        :index=>3,
        :account_dst_id=>[2]},
      {:id=>4,
        :value=>20.0,
        :desc=>"Restaurant",
        :revision=>nil,
        :account_src_id=>[4],
        :global_id=>"5544436cf81115c6faf577a7e2307e92-4",
        :index=>4,
        :account_dst_id=>[2]}], 
      movs.collect{ |m| 
      m.to_hash.delete_if{|k,v| k == :date
      } }
			
    assert_equal [{:global_id=>"5544436cf81115c6faf577a7e2307e92-5",
        :multiplier=>-1.0,
        :total=>"0",
        :desc=>"Full description",
        :account_id=>[1],
        :name=>"Lending",
        :index=>9,
        :id=>5},
      {:id=>1,
        :multiplier=>1.0,
        :total=>"0",
        :desc=>"Full description",
        :account_id=>0,
        :name=>"Root",
        :global_id=>"5544436cf81115c6faf577a7e2307e92-1",
        :index=>1},
      {:id=>2,
        :multiplier=>-1.0,
        :total=>"1040.0",
        :desc=>"Full description",
        :account_id=>[1],
        :name=>"Cash",
        :global_id=>"5544436cf81115c6faf577a7e2307e92-2",
        :index=>5},
      {:id=>3,
        :multiplier=>1.0,
        :total=>"1100.0",
        :desc=>"Full description",
        :account_id=>[1],
        :name=>"Income",
        :global_id=>"5544436cf81115c6faf577a7e2307e92-3",
        :index=>8},
      {:id=>4,
        :multiplier=>1.0,
        :total=>"-60.0",
        :desc=>"Full description",
        :account_id=>[1],
        :name=>"Outcome",
        :global_id=>"5544436cf81115c6faf577a7e2307e92-4",
        :index=>10}], 
      accs.collect{|a| a.to_hash}
		
    assert_equal [{:full=>"5544436cf81115c6faf577a7e2307e92",
        :pass=>"152020265102732202950475079275867584513",
        :account_index=>11,
        :movement_index=>5,
        :name=>"local",
        :id=>1},
      {:pass=>"bar",
        :full=>"foo bar",
        :account_index=>0,
        :movement_index=>0,
        :name=>"foo",
        :id=>2}],
      users.collect{|u| u.to_hash}
  end
	
  def test_mov
    # Test all methods copied into Movements
    mov = Movements.find_by_desc( "Train" )
		
    assert_equal 40, mov.value
    assert_equal "Train\r5544436cf81115c6faf577a7e2307e92-3\t40.0\t2012-07-02\t" + 
      "5544436cf81115c6faf577a7e2307e92-4\t5544436cf81115c6faf577a7e2307e92-2", 
      mov.to_s
    assert_equal "{\"str\":\"Train\\r5544436cf81115c6faf577a7e2307e92-3\\t40.0\\t" +
      "2012-07-02\\t5544436cf81115c6faf577a7e2307e92-4\\t" + 
      "5544436cf81115c6faf577a7e2307e92-2\"}", 
      mov.to_json
    assert_equal( {:global_id=>"5544436cf81115c6faf577a7e2307e92-2",
        :desc=>"Full description",
        :total=>"1040.0",
        :multiplier=>-1.0,
        :account_id=>[1],
        :name=>"Cash",
        :id=>2,
        :index=>5}, 
      mov.get_other_account( mov.account_src ).to_hash )
		
    # This is 11th of July 2012
    assert_equal "1040.0", @cash.total

    mov.set( "new", "11/7/12", 120, @cash, @income )
    assert_equal "new\r5544436cf81115c6faf577a7e2307e92-3\t120\t2012-07-11\t" + 
      "5544436cf81115c6faf577a7e2307e92-2\t5544436cf81115c6faf577a7e2307e92-3", 
      mov.to_s
    assert_equal 1200, @cash.total
		
    assert_equal 120.0, mov.get_value( @cash )
		
    assert_equal true, mov.is_in_account( @cash )
    assert_equal false, mov.is_in_account( @outcome )
		
    assert_equal 5, mov.get_index
  end
	
  def test_movs
    assert_equal "1040.0", @cash.total
    assert_equal "-60.0", @outcome.total
		
    # Overwriting movement with id 4: Restaurant with value = 20.0
    mov = Movements.from_s "Restaurant\r5544436cf81115c6faf577a7e2307e92-4\t10" + 
      "\t2012-07-12\t" + 
      "5544436cf81115c6faf577a7e2307e92-4\t5544436cf81115c6faf577a7e2307e92-2"
    assert_equal( 1050.0, @cash.total )
    assert_equal( -50.0, @outcome.total )
    assert_equal( 10.0, mov.value )
		
    # Creating new movement
    newmov = Movements.from_s "Car\r5544436cf81115c6faf577a7e2307e92-5\t100" + 
      "\t2012-07-12\t" +
      "5544436cf81115c6faf577a7e2307e92-4\t5544436cf81115c6faf577a7e2307e92-2"
    assert_equal 950.0, @cash.total
    assert_equal( -150.0, @outcome.total )
    assert_equal( 100.0, newmov.value )
		
    # Testing JSON
    mov_json = newmov.to_json
    assert_equal "{\"str\":\"Car\\r5544436cf81115c6faf577a7e2307e92-5\\t100.0\\t" + 
      "2012-07-12\\t5544436cf81115c6faf577a7e2307e92-4\\t" + 
      "5544436cf81115c6faf577a7e2307e92-2\"}", 
      mov_json
    newmov.value = 50
    assert_equal( 1000.0, @cash.total )
    newmov = Movements.from_json mov_json
    assert_equal( 950.0, @cash.total )
    assert_equal( 100.0, newmov.value )
		
    assert_equal 8, @local.movement_index
		
    Movements.create( 'test_mov', '2012-02-29', 100.0, @cash, @outcome )
    assert_equal 9, @local.movement_index
  end
	
  def test_account
    tree = []
    @root.get_tree{|a| tree.push a.name }
    assert_equal "Root-Lending-Cash-Income-Outcome", tree.join("-")
		
    assert_equal "Root", @root.path
    assert_equal "Root::Outcome", @outcome.path
		
    assert_equal 10, @outcome.index
    @outcome.new_index
    assert_equal 11, @outcome.index
		
    foo = Users.create( "foo", "foo bar", "foobar" )
    box = Accounts.create( "Cashbox", "Running cash", @cash, 
      "5544436cf81115c6faf577a7e2307e92-7")
		
    assert_equal "1040.0", @cash.total
    @cash.set_nochildmult( "Cash_2", "All money", @root, 1, [ foo.name ] )
    assert_equal "Cash_2", @cash.name
    assert_equal "All money", @cash.desc
    assert_equal 1, @cash.multiplier
    assert_equal( -1, box.multiplier )
    assert_equal( -1040.0, @cash.total )
		
    assert_equal([{:value=>20.0,
          :desc=>"Restaurant",
          :account_src_id=>[4],
          :revision=>nil,
          :account_dst_id=>[2],
          :global_id=>"5544436cf81115c6faf577a7e2307e92-4",
          :index=>4,
          :id=>4},
        {:value=>100.0,
          :desc=>"Gift",
          :account_src_id=>[2],
          :revision=>nil,
          :account_dst_id=>[3],
          :global_id=>"5544436cf81115c6faf577a7e2307e92-2",
          :index=>2,
          :id=>2},
        {:value=>40.0,
          :desc=>"Train",
          :account_src_id=>[4],
          :revision=>nil,
          :account_dst_id=>[2],
          :global_id=>"5544436cf81115c6faf577a7e2307e92-3",
          :index=>3,
          :id=>3},
        {:value=>1000.0,
          :desc=>"Salary",
          :account_src_id=>[2],
          :revision=>nil,
          :account_dst_id=>[3],
          :global_id=>"5544436cf81115c6faf577a7e2307e92-1",
          :index=>1,
          :id=>1}], 
      @cash.movements.collect{|m| m.to_hash.delete_if{|k,v| k == :date
        }} )
		
    assert_equal "All money\r5544436cf81115c6faf577a7e2307e92-2\t-1040.0\t" + 
      "Cash_2\t1\t5544436cf81115c6faf577a7e2307e92-1", 
      @cash.to_s
		
    assert_equal false, @cash.is_empty
    box = Accounts.create( "Cashbox", "Running cash", @cash, 
      "5544436cf81115c6faf577a7e2307e92-8")
    assert_equal true, box.is_empty
		
    assert_equal( 1, @cash.multiplier )
    assert_equal( 1, box.multiplier )
    @cash.set_child_multipliers( -1 )
    assert_equal( -1, @cash.multiplier )
    assert_equal( -1, box.multiplier )
		
    assert_equal 7, Accounts.search_all.length
    box.delete
    assert_equal 6, Accounts.search_all.length
  end
	
  def test_accounts
    assert_equal 2, @cash.id
		
    box = Accounts.create( "Cashbox", "Running cash", @cash, 
      "5544436cf81115c6faf577a7e2307e92-8")
    assert_equal( {:multiplier=>-1,
        :desc=>"Running cash",
        :total=>"0",
        :account_id=>[2],
        :global_id=>"5544436cf81115c6faf577a7e2307e92-8",
        :name=>"Cashbox",
        :id=>6,
        :index=>11}, box.to_hash )
    assert_equal "Root::Cash::Cashbox", box.path
    assert_equal( -1, @cash.multiplier )
    assert_equal( -1, box.multiplier )
		
    box_s = box.to_s
    box.delete
    box = Accounts.from_s( box_s )
    assert_equal( {:multiplier=>-1.0,
        :desc=>"Running cash",
        :total=>0.0,
        :account_id=>[2],
        :global_id=>"5544436cf81115c6faf577a7e2307e92-8",
        :name=>"Cashbox",
        :id=>7,
        :index=>13}, box.to_hash )
		
    course = Accounts.create_path("Root::Income::Course", "course")
    assert_equal "Root::Income::Course", course.get_path
    assert_equal "5544436cf81115c6faf577a7e2307e92-8", course.global_id

    ccard = Accounts.create_path("Credit::Card", "credit-card")
    assert_equal "Credit::Card", ccard.get_path
    assert_equal "5544436cf81115c6faf577a7e2307e92-10", ccard.global_id
  end
	
  def test_users
    Users.create( "foo2", "foo foo", "foo2bar" )
    foo = Users.find_by_name( "foo2" )
    assert_equal "foo foo", foo.full
    assert_equal "foo2bar", foo.pass
    assert_equal 0, foo.movement_index
    assert_equal 0, foo.account_index
		
    foo.update_movement_index
    assert_equal 4, foo.movement_index
    foo.update_account_index
    assert_equal 10, foo.account_index
  end
	
  def test_remote
    rem = Remotes.create( :url => "http://localhost:3302/acaccount",
      :name => "foo", :pass => "bar" )
    assert_equal 0, rem.account_index
    assert_equal 0, rem.movement_index
		
    rem.update_movement_index
    assert_equal 4, rem.movement_index
    rem.update_account_index
    assert_equal 10, rem.account_index

    rem2 = Remotes.create( :url => "http://localhost:3302/acaccount",
      :name => "foo", :pass => "bar", :account_index => 10,
      :movement_index => 20 )
    assert_equal 10, rem2.account_index
    assert_equal 20, rem2.movement_index
  end
	
  def test_merge_get
    rep = ACaccess.get( "version/foo,ba" )
    assert_equal "User foo not known with pass ba", rep

    rep = ACaccess.get( "version/foo,bar" )
    assert_equal "4096", rep
		
    rep = ACaccess.get( "index/foo,bar")
    assert_equal "11,5", rep

    rep = ACaccess.get( "accounts_get_one/5544436cf81115c6faf577a7e2307e92-2" + 
        "/foo,bar")
    assert_equal "Full description\r5544436cf81115c6faf577a7e2307e92-2\t" +
      "1040.0\tCash\t-1.0\t5544436cf81115c6faf577a7e2307e92-1", rep

    rep = ACaccess.get( "accounts_get/foo,bar")
    assert_equal "Full description\r5544436cf81115c6faf577a7e2307e92-1\t0\t" +
      "Root\t1.0\t\nFull description\r5544436cf81115c6faf577a7e2307e92-5\t0" +
      "\tLending\t-1.0\t5544436cf81115c6faf577a7e2307e92-1\nFull description" +
      "\r5544436cf81115c6faf577a7e2307e92-2\t1040.0\tCash\t-1.0\t" +
      "5544436cf81115c6faf577a7e2307e92-1\nFull description\r" +
      "5544436cf81115c6faf577a7e2307e92-3\t1100.0\tIncome\t1.0\t" +
      "5544436cf81115c6faf577a7e2307e92-1\nFull description\r" +
      "5544436cf81115c6faf577a7e2307e92-4\t-60.0\tOutcome\t1.0\t" +
      "5544436cf81115c6faf577a7e2307e92-1\n", rep

    rep = ACaccess.get( "accounts_get/foo,bar")
    assert_equal "", rep

    rep = ACaccess.get( "accounts_get_all/foo,bar")
    assert_equal "Full description\r5544436cf81115c6faf577a7e2307e92-1\t0" +
      "\tRoot\t1.0\t\tRoot\nFull description\r" +
      "5544436cf81115c6faf577a7e2307e92-5\t0\tLending\t-1.0\t" +
      "5544436cf81115c6faf577a7e2307e92-1\tRoot::Lending\nFull description" +
      "\r5544436cf81115c6faf577a7e2307e92-2\t1040.0\tCash\t-1.0\t" +
      "5544436cf81115c6faf577a7e2307e92-1\tRoot::Cash\nFull description\r" +
      "5544436cf81115c6faf577a7e2307e92-3\t1100.0\tIncome\t1.0\t" +
      "5544436cf81115c6faf577a7e2307e92-1\tRoot::Income\nFull description\r" +
      "5544436cf81115c6faf577a7e2307e92-4\t-60.0\tOutcome\t1.0\t" +
      "5544436cf81115c6faf577a7e2307e92-1\tRoot::Outcome\n", rep
		
    rep = ACaccess.get( "movements_get_one/5544436cf81115c6faf577a7e2307e92-4/foo,bar")
    assert_equal "Restaurant\r5544436cf81115c6faf577a7e2307e92-4\t20.0\t" +
      "2012-07-11\t5544436cf81115c6faf577a7e2307e92-4\t" +
      "5544436cf81115c6faf577a7e2307e92-2", rep

    rep = ACaccess.get( "movements_get_all/0,100/foo,bar")
    assert_equal "Salary\r5544436cf81115c6faf577a7e2307e92-1\t1000.0\t" +
      "2012-07-01\t5544436cf81115c6faf577a7e2307e92-2\t" +
      "5544436cf81115c6faf577a7e2307e92-3\nGift\r" +
      "5544436cf81115c6faf577a7e2307e92-2\t100.0\t2012-07-10\t" +
      "5544436cf81115c6faf577a7e2307e92-2\t5544436cf81115c6faf577a7e2307e92-3\n" +
      "Train\r5544436cf81115c6faf577a7e2307e92-3\t40.0\t2012-07-02\t" +
      "5544436cf81115c6faf577a7e2307e92-4\t5544436cf81115c6faf577a7e2307e92-2\n" +
      "Restaurant\r5544436cf81115c6faf577a7e2307e92-4\t20.0\t2012-07-11\t" +
      "5544436cf81115c6faf577a7e2307e92-4\t5544436cf81115c6faf577a7e2307e92-2\n", 
      rep

    rep = ACaccess.get( "movements_get/foo,bar")
    assert_equal "", rep
  end
	
  def test_merge_post
    input = { 'user' => 'foo', 'pass' => 'bar' }
		
    rep = ACaccess.post( 'account_get_id', input.merge('account' => 'Root'))
    assert_equal "1", rep
    rep = ACaccess.post( 'account_get_id', input.merge('account' => 'Root::Cash'))
    assert_equal "2", rep
		
    mov_pizza = "Pizza\r5544436cf81115c6faf577a7e2307e92-5\t12.0\t" +
      "2012-07-20\t5544436cf81115c6faf577a7e2307e92-4\t" +
      "5544436cf81115c6faf577a7e2307e92-2"
    mov_panini = "Panini\r5544436cf81115c6faf577a7e2307e92-6\t14.0\t" +
      "2012-07-21\t5544436cf81115c6faf577a7e2307e92-4\t" +
      "5544436cf81115c6faf577a7e2307e92-2"
    assert_equal "-60.0", @outcome.total
    assert_equal "1040.0", @cash.total
    rep = ACaccess.post( 'movements_put', input.merge( 'movements' => 
          [{ :str => mov_pizza }.to_json, { :str => mov_panini }.to_json].to_json))
    assert_equal "ok", rep

    mov_pizza_merged = Movements.find_by_desc( 'Pizza' )
    assert_equal 12.0, mov_pizza_merged.value
    mov_panini_merged = Movements.find_by_desc( 'Panini' )
    assert_equal 14.0, mov_panini_merged.value
    assert_equal( -86.0, @outcome.total )
    assert_equal 1014.0, @cash.total
		
    Entities.Movements.load
    mov_pizza_merged = Movements.find_by_desc( 'Pizza' )
    assert_equal "2012-07-20", mov_pizza_merged.date.to_s
    mov_panini_merged = Movements.find_by_desc( 'Panini' )
    assert_equal "2012-07-21", mov_panini_merged.date.to_s

    rep = ACaccess.post( 'movements_put', input.merge( 'movements' => 
          [{ :str => mov_pizza.sub("12.0", "22.0") }.to_json, 
          { :str => mov_panini.sub("14.0", "24.0") }.to_json].to_json))
    assert_equal "ok", rep
    mov_pizza_merged = Movements.find_by_desc( 'Pizza' )
    assert_equal 22.0, mov_pizza_merged.value
    mov_panini_merged = Movements.find_by_desc( 'Panini' )
    assert_equal 24.0, mov_panini_merged.value

  end
	
  # This is only relevant when testing with big data from solar
  def tes_gettree
    tree = []
    Accounts.matches_by_account_id(0).to_a.each{|a|
      a.get_tree{ |b| tree.push b.index }
    }
    tree_d = []
    Accounts.matches_by_account_id(0).to_a.each{|a|
      a.get_tree_debug{ |b| tree_d.push b.index }
    }

    assert_equal 389, tree.count
    assert_equal 389, tree_d.count
  end
	
  def setup_clean_accounts
    Entities.delete_all_data()
    Users.create( 'local', '123456789', 'bar' )
    @root = Accounts.create( 'Root' )
    @income = Accounts.create( 'Income', '', @root )
    @spending = Accounts.create( 'Spending', '', @root )
    @cash = Accounts.create( 'Cash', '', @root )		
    @cash.multiplier = -1
  end
	
  def get_sorted_accounts( name )
    Accounts.search_by_name( name ).sort{
      |a,b| a.path <=> b.path
    }
  end
	
  def test_archive
    setup_clean_accounts
    @base = []
    [ 1001, 1009, 1012, 1106, 1112, 1201 ].each{|b|
      @base[b] = Accounts.create "Base_#{b}", "", @income
    }
		
    def testmov( base, cash, years )
      d = 1
      years.each{|y|
        Movements.create( "inscr #{base.desc}", "#{y}-01-2#{d}",
          y.to_i + d, base, cash )
        d += 1
      }
    end
		
    # This should never happen, but still it's possible...
    Movements.create 'buggy', '2011-01-01', 100, @income, @cash

    # Create different test cases in different accounts
    # This has most == last == 2010
    testmov( @base[1001], @cash, %w( 2010 2010 ) )
    # This has most == 2010, last == 2011
    testmov( @base[1009], @cash, %w( 2010 2010 2011 ) )
    # This has most == last == 2011
    testmov( @base[1012], @cash, %w( 2010 2011 2011 ) )
    # This has most == 2011, last == 2012
    testmov( @base[1106], @cash, %w( 2011 2011 2012 ) )
    # This has most == last == 2012 and movements in 2011
    testmov( @base[1112], @cash, %w( 2011 2012 2012 ) )
    # This has most == last == 2012 and no movements in 2011
    testmov( @base[1201], @cash, %w( 2012 2012 ) )
		
    Accounts.archive( 1, 2012 )
		
    # Name, account-count, movs-count, path of first occurence
    [ [1001,1,2,'Archive::2010::Income::Base_1001'], 
      [1009,3,2,'Archive::2010::Income::Base_1009'], 
      [1012,3,1,'Archive::2010::Income::Base_1012'], 
      [1106,2,2,'Archive::2011::Income::Base_1106'], 
      [1112,2,1,'Archive::2011::Income::Base_1112'], 
      [1201,1,2,'Root::Income::Base_1201'] ].each{|b|
      name, count, movs, path = b
      @base[name] = get_sorted_accounts( "Base_#{name}" )
      assert_equal count, @base[name].count, "Count for #{name}"
      assert_equal movs, @base[name].first.movements.count, "movs for #{name}"
      assert_equal path, @base[name].first.path, "path for #{name}"
    }
  end
	
  def add_movs
    Movements.create( "Year 2011", "2011-01-01", 10, @cash, @income )
    Movements.create( "Year 2011", "2012-05-01", 20, @cash, @income )
    Movements.create( "Year 2012", "2012-06-01", 30, @cash, @income )
  end

  def test_archive_start_june	
    setup_clean_accounts
    add_movs
    Accounts.archive( 6, 2012 )
    incomes = get_sorted_accounts( "Income" )
		
    assert_equal 3, incomes.length
    assert_equal 1, incomes[0].movements.length
    assert_equal 2, incomes[1].movements.length
    assert_equal 2, incomes[2].movements.length
  end
	
  def test_archive_sum_up
    # Make sure that everything still sums up
    setup_clean_accounts
    add_movs
    @cash.update_total
		
    assert_equal 60, Accounts.find_by_name( "Cash" ).total
    Accounts.archive( 6, 2012 )
    cashs = get_sorted_accounts( "Cash" )
    (0..2).each{|i|
      dputs( 3 ){ "Path for #{i} is #{cashs[i].get_path}" }
    }
    assert_equal 10, cashs[0].total
    assert_equal 30, cashs[1].total
    assert_equal 60, cashs[2].total

    # Test two consecutive runs on the archive like 2013, then 2014, and
    # make sure that the accounts that hold only a "final"-movement get
    # deleted
    setup_clean_accounts
    add_movs
    Accounts.archive( 6, 2013 )
    incomes = get_sorted_accounts( "Income" )
    assert_equal 4, incomes.count
    assert_equal 60, incomes[3].total
		
    Accounts.archive( 6, 2014 )
    incomes = get_sorted_accounts( "Income" )
    ddputs(3){incomes.inspect}
    # We lost the actual account, as it should be empty
    assert_equal 3, incomes.count
    assert_equal 60, incomes[2].total
		
  end

  def test_creation
    Entities.delete_all_data()
    ACQooxView::check_db
  end
	
  def load_big_data
    FileUtils.cp( "db.solar", "data/compta.db" )		
    Entities.Movements.load
    Entities.Accounts.load
    Entities.Users.load
  end
		
  def tes_big_data
    load_big_data
    Accounts.archive( 1, 2012 )
  end
	
  def test_archive_2
    load_big_data
    Accounts.archive( 1, 2012, 
      Accounts.get_by_path( "Root::Caisses::Centre::Josué" ) )
  end

  def test_archive_3
    load_big_data
    Accounts.archive( 1, 2012, 
      Accounts.get_by_path( "Root::Caisses::Centre::Rubia Centre" ) )
  end

  def test_get_by_path
    cash = Accounts.get_by_path( "Root::Cash" )
		
    assert_equal "Cash", cash.name
  end
	
  def test_speed
    require 'rubygems'
    require 'perftools'
    PerfTools::CpuProfiler.start("/tmp/profile") do
      (2010..2012).each{|year|
        dputs( 0 ){ "Doing year #{year}" }
        (1..12).each{|month|
          (1..10).each{|day|
            (1..1).each{|t|
              date = "#{year}-#{month}-#{day}"
              Movements.create( "Test #{date}", date, t, @cash, @income )
            }
          }
        }
      }
    end
  end
	
  def test_round
    a = 2.563
    assert_equal Float, a.class
    assert_equal 3, a.round
    assert_equal 2.6, a.round( 1 )
    assert_equal 2.56, a.round( 2 )
  end
end

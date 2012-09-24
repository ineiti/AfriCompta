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
  end

  def teardown
  end

  def test_db
		movs = Movements.search_all
		assert_equal 4, movs.length
		accs = Accounts.search_all
		assert_equal 4, accs.length
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
			
		assert_equal [{:id=>1,
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
				:index=>3},
			{:id=>4,
				:multiplier=>1.0,
				:total=>"-60.0",
				:desc=>"Full description",
				:account_id=>[1],
				:name=>"Outcome",
				:global_id=>"5544436cf81115c6faf577a7e2307e92-4",
				:index=>4}], 
			accs.collect{|a| a.to_hash}
		
		assert_equal [{:full=>"5544436cf81115c6faf577a7e2307e92",
				:pass=>"152020265102732202950475079275867584513",
				:account_index=>6,
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
			"12/7/2012\\t5544436cf81115c6faf577a7e2307e92-4\\t" + 
			"5544436cf81115c6faf577a7e2307e92-2\"}", 
			mov_json
		newmov.value = 50
		assert_equal( 1000.0, @cash.total )
		newmov = Movements.from_json mov_json
		assert_equal( 950.0, @cash.total )
		assert_equal( 100.0, newmov.value )
	end
	
	def test_account
		tree = []
		@root.get_tree{|a| tree.push a.name }
		assert_equal "Root-Cash-Income-Outcome", tree.join("-")
		
		assert_equal "Root::Outcome", @outcome.path
		
		assert_equal 4, @outcome.index
		@outcome.new_index
		assert_equal 6, @outcome.index
		
		foo = Users.create( "foo", "foo bar", "foobar" )
		box = Accounts.create( "Cashbox", "Running cash", @cash, 
			"5544436cf81115c6faf577a7e2307e92-7")
		
		assert_equal "1040.0", @cash.total
		@cash.set_nochildmult( "Cash_2", "All money", @root, 1, [ foo.name ] )
		assert_equal "Cash_2", @cash.name
		assert_equal "All money", @cash.desc
		assert_equal 1, @cash.multiplier
		assert_equal( -1, box.multiplier )
		assert_equal "1040.0", @cash.total
		
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
		
		assert_equal "All money\r5544436cf81115c6faf577a7e2307e92-2\t1040.0\t" + 
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
		
		assert_equal 6, Accounts.search_all.length
		box.delete
		assert_equal 5, Accounts.search_all.length
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
				:index=>7}, box.to_hash )
		assert_equal "Root::Cash::Cashbox", box.path
		assert_equal( -1, @cash.multiplier )
		assert_equal( -1, box.multiplier )
		
		box_s = box.to_s
		box.delete
		box = Accounts.from_s( box_s )
		assert_equal( {:multiplier=>-1.0,
				:desc=>"Running cash",
				:total=>"0",
				:account_id=>[2],
				:global_id=>"5544436cf81115c6faf577a7e2307e92-8",
				:name=>"Cashbox",
				:id=>6,
				:index=>9}, box.to_hash )
		
		course = Accounts.create_path("Root::Income::Course", "course")
		assert_equal "Root::Income::Course", course.get_path

		ccard = Accounts.create_path("Credit::Card", "credit-card")
		assert_equal "Credit::Card", ccard.get_path
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
		assert_equal 5, foo.account_index
	end
	
	def test_remote
		rem = Remotes.create( :url => "http://localhost:3302/acaccount",
			:name => "foo", :pass => "bar" )
		assert_equal 0, rem.account_index
		assert_equal 0, rem.movement_index
		
		rem.update_movement_index
		assert_equal 4, rem.movement_index
		rem.update_account_index
		assert_equal 5, rem.account_index

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
		assert_equal "6,5", rep

		rep = ACaccess.get( "accounts_get_one/5544436cf81115c6faf577a7e2307e92-2" + 
				"/foo,bar")
		assert_equal "Full description\r5544436cf81115c6faf577a7e2307e92-2\t" +
			"1040.0\tCash\t-1.0\t5544436cf81115c6faf577a7e2307e92-1", rep

		rep = ACaccess.get( "accounts_get/foo,bar")
		assert_equal "Full description\r5544436cf81115c6faf577a7e2307e92-1\t0\tRoot" +
			"\t1.0\t\nFull description\r5544436cf81115c6faf577a7e2307e92-2\t1040.0\t" +
			"Cash\t-1.0\t5544436cf81115c6faf577a7e2307e92-1\nFull description\r" +
			"5544436cf81115c6faf577a7e2307e92-3\t1100.0\tIncome\t1.0\t" +
			"5544436cf81115c6faf577a7e2307e92-1\nFull description\r" +
			"5544436cf81115c6faf577a7e2307e92-4\t-60.0\tOutcome\t1.0\t" +
			"5544436cf81115c6faf577a7e2307e92-1\n", rep

		rep = ACaccess.get( "accounts_get/foo,bar")
		assert_equal "", rep

		rep = ACaccess.get( "accounts_get_all/foo,bar")
		assert_equal "Full description\r5544436cf81115c6faf577a7e2307e92-1\t0\t" +
			"Root\t1.0\t\tRoot::\nFull description\r5544436cf81115c6faf577a7e2307e92-2" +
			"\t1040.0\tCash\t-1.0\t5544436cf81115c6faf577a7e2307e92-1\tRoot::Cash\n" +
			"Full description\r5544436cf81115c6faf577a7e2307e92-3\t1100.0\tIncome\t" +
			"1.0\t5544436cf81115c6faf577a7e2307e92-1\tRoot::Income\nFull description" +
			"\r5544436cf81115c6faf577a7e2307e92-4\t-60.0\tOutcome\t1.0\t" +
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
			"2012-07-11\t5544436cf81115c6faf577a7e2307e92-4\t" +
			"5544436cf81115c6faf577a7e2307e92-2"
		mov_panini = "Panini\r5544436cf81115c6faf577a7e2307e92-6\t14.0\t" +
			"2012-07-11\t5544436cf81115c6faf577a7e2307e92-4\t" +
			"5544436cf81115c6faf577a7e2307e92-2"
		assert_equal "-60.0", @outcome.total
		assert_equal "1040.0", @cash.total
		rep = ACaccess.post( 'movements_put', input.merge( 'movements' => 
					[{ :str => mov_pizza }.to_json, { :str => mov_panini }.to_json].to_json))
		assert_equal "ok", rep
		assert_equal 12.0, Movements.find_by_desc( 'Pizza' ).value
		assert_equal 14.0, Movements.find_by_desc( 'Panini' ).value
		assert_equal( -86.0, @outcome.total )
		assert_equal 1014.0, @cash.total
	end
	
	# This is only relevant when testing with big data from solar
	def tes_gettree
		tree = []
		Accounts.match_by_account_id(0).to_a.each{|a|
			a.get_tree{ |b| tree.push b.index }
		}
		tree_d = []
		Accounts.match_by_account_id(0).to_a.each{|a|
			a.get_tree_debug{ |b| tree_d.push b.index }
		}

		assert_equal 389, tree.count
		assert_equal 389, tree_d.count
	end

end

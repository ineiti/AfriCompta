require 'test/unit'

TESTBIG=false

class TC_AfriCompta < Test::Unit::TestCase
  def setup
    dputs(1) { 'Setting up - deleting and reloading everything' }
    Entities.delete_all_data

    dputs(2) { 'Resetting SQLite' }
    SQLite.dbs_close_all
    dputs(2) { 'Putting testGestion' }
    FileUtils.cp('db.testGestion', 'data/compta.db')
    SQLite.dbs_open_load_migrate

    dputs(3) { 'And searching for some accounts' }
    @root = Accounts.match_by_name('Root')
    @cash = Accounts.match_by_name('Cash')
    @income = Accounts.match_by_name('Income')
    @outcome = Accounts.match_by_name('Outcome')
    @local = Users.match_by_name('local')
  end

  def teardown
    Entities.save_all
  end

  # This should work - but for some reason the indexes get mixed up
  # and end up being strings instead of integers....
  def tes_load_db
    setup_clean_accounts
    Movements.create('any', '2013-01-01', 10, @cash, @income)

    SQLite.dbs_close_all
    Accounts.delete_all(true)
    SQLite.dbs_open_load

    Accounts.dump true
  end

  def test_db
    movs = Movements.search_all
    assert_equal 4, movs.length
    accs = Accounts.search_all
    assert_equal 5, accs.length
    users = Users.search_all
    assert_equal 2, users.length

    assert_equal [{:id => 1,
                   :value => 1000.0,
                   :desc => 'Salary',
                   :revision => nil,
                   :account_src_id => [2],
                   :global_id => '5544436cf81115c6faf577a7e2307e92-1',
                   :rev_index => 1,
                   :index => 1,
                   :account_dst_id => [3]},
                  {:id => 2,
                   :value => 100.0,
                   :desc => 'Gift',
                   :revision => nil,
                   :account_src_id => [2],
                   :global_id => '5544436cf81115c6faf577a7e2307e92-2',
                   :rev_index => 2,
                   :index => 2,
                   :account_dst_id => [3]},
                  {:id => 3,
                   :value => 40.0,
                   :desc => 'Train',
                   :revision => nil,
                   :account_src_id => [4],
                   :global_id => '5544436cf81115c6faf577a7e2307e92-3',
                   :rev_index => 3,
                   :index => 3,
                   :account_dst_id => [2]},
                  {:id => 4,
                   :value => 20.0,
                   :desc => 'Restaurant',
                   :revision => nil,
                   :account_src_id => [4],
                   :global_id => '5544436cf81115c6faf577a7e2307e92-4',
                   :rev_index => 4,
                   :index => 4,
                   :account_dst_id => [2]}],
                 movs.collect { |m|
                   m.to_hash.delete_if { |k, v| k == :date
                   } }.sort { |a, b| a[:id] <=> b[:id] }

    assert_equal [
                     {:id => 1,
                      :multiplier => 1.0,
                      :total => '0',
                      :desc => 'Full description',
                      :account_id => 0,
                      :name => 'Root',
                      :global_id => '5544436cf81115c6faf577a7e2307e92-1',
                      :deleted => false,
                      :keep_total => false,
                      :index => 1,
                      :rev_index => 1},
                     {:id => 2,
                      :multiplier => -1.0,
                      :total => '1040.0',
                      :desc => 'Full description',
                      :account_id => 1,
                      :name => 'Cash',
                      :global_id => '5544436cf81115c6faf577a7e2307e92-2',
                      :deleted => false,
                      :keep_total => true,
                      :index => 5,
                      :rev_index => 2},
                     {:id => 3,
                      :multiplier => 1.0,
                      :total => '1100.0',
                      :desc => 'Full description',
                      :account_id => 1,
                      :name => 'Income',
                      :global_id => '5544436cf81115c6faf577a7e2307e92-3',
                      :deleted => false,
                      :keep_total => false,
                      :index => 8,
                      :rev_index => 3},
                     {:id => 4,
                      :multiplier => 1.0,
                      :total => '-60.0',
                      :desc => 'Full description',
                      :account_id => 1,
                      :name => 'Outcome',
                      :global_id => '5544436cf81115c6faf577a7e2307e92-4',
                      :deleted => false,
                      :keep_total => false,
                      :index => 10,
                      :rev_index => 4},
                     {:global_id => '5544436cf81115c6faf577a7e2307e92-5',
                      :multiplier => -1.0,
                      :total => '0',
                      :desc => 'Full description',
                      :account_id => 1,
                      :name => 'Lending',
                      :index => 9,
                      :rev_index => 5,
                      :deleted => false,
                      :keep_total => true,
                      :id => 5}],
                 accs.collect { |a| a.to_hash }.sort { |a, b| a[:id] <=> b[:id] }

    assert_equal [{:full => '5544436cf81115c6faf577a7e2307e92',
                   :pass => '152020265102732202950475079275867584513',
                   :account_index => 11,
                   :movement_index => 5,
                   :name => 'local',
                   :id => 1},
                  {:pass => 'bar',
                   :full => 'foo bar',
                   :account_index => 0,
                   :movement_index => 0,
                   :name => 'foo',
                   :id => 2}],
                 users.collect { |u| u.to_hash }
  end

  def test_mov
    # Test all methods copied into Movements
    mov = Movements.match_by_desc('Train')

    assert_equal 40, mov.value
    assert_equal "Train\r5544436cf81115c6faf577a7e2307e92-3\t40.000\t2012-07-02\t" +
                     "5544436cf81115c6faf577a7e2307e92-4\t5544436cf81115c6faf577a7e2307e92-2",
                 mov.to_s
    assert_equal "{\"str\":\"Train\\r5544436cf81115c6faf577a7e2307e92-3\\t40.000\\t" +
                     "2012-07-02\\t5544436cf81115c6faf577a7e2307e92-4\\t" +
                     "5544436cf81115c6faf577a7e2307e92-2\"}",
                 mov.to_json
    assert_equal({:global_id => '5544436cf81115c6faf577a7e2307e92-2',
                  :desc => 'Full description',
                  :total => '1040.0',
                  :multiplier => -1.0,
                  :account_id => 1,
                  :name => 'Cash',
                  :id => 2,
                  :deleted => false,
                  :keep_total => true,
                  :rev_index => 2,
                  :index => 5
                 },
                 mov.get_other_account(mov.account_src).to_hash)

    # This is 11th of July 2012
    assert_equal '1040.0', @cash.total

    mov.set('new', '11/7/12', 120, @cash, @income)
    assert_equal "new\r5544436cf81115c6faf577a7e2307e92-3\t120.000\t2012-07-11\t" +
                     "5544436cf81115c6faf577a7e2307e92-2\t5544436cf81115c6faf577a7e2307e92-3",
                 mov.to_s
    assert_equal 1200, @cash.total

    assert_equal 120.0, mov.get_value(@cash)

    assert_equal true, mov.is_in_account(@cash)
    assert_equal false, mov.is_in_account(@outcome)

    assert_equal 11, mov.get_index
  end

  def test_movs
    assert_equal '1040.0', @cash.total
    assert_equal '-60.0', @outcome.total

    # Overwriting movement with id 4: Restaurant with value = 20.0
    mov = Movements.from_s "Restaurant\r5544436cf81115c6faf577a7e2307e92-4\t10" +
                               "\t2012-07-12\t" +
                               "5544436cf81115c6faf577a7e2307e92-4\t5544436cf81115c6faf577a7e2307e92-2"
    assert_equal(1050.0, @cash.total)
    assert_equal(-50.0, @outcome.total)
    assert_equal(10.0, mov.value)

    # Creating new movement
    newmov = Movements.from_s "Car\r5544436cf81115c6faf577a7e2307e92-5\t100" +
                                  "\t2012-07-12\t" +
                                  "5544436cf81115c6faf577a7e2307e92-4\t5544436cf81115c6faf577a7e2307e92-2"
    assert_equal 950.0, @cash.total
    assert_equal(-150.0, @outcome.total)
    assert_equal(100.0, newmov.value)

    # Testing JSON
    mov_json = newmov.to_json
    assert_equal "{\"str\":\"Car\\r5544436cf81115c6faf577a7e2307e92-5\\t100.000\\t" +
                     "2012-07-12\\t5544436cf81115c6faf577a7e2307e92-4\\t" +
                     "5544436cf81115c6faf577a7e2307e92-2\"}",
                 mov_json
    assert_equal(950.0, @cash.total)
    newmov.value = 50
    assert_equal(1000.0, @cash.total)
    newmov = Movements.from_json mov_json
    assert_equal(950.0, @cash.total)
    assert_equal(100.0, newmov.value)

    assert_equal 23, @local.movement_index

    Movements.create('test_mov', '2012-02-29', 100.0, @cash, @outcome)
    assert_equal 25, @local.movement_index
  end

  def test_account
    tree = []
    @root.get_tree { |a| tree.push a.name }
    assert_equal %w( Root Lending Cash Income Outcome ).sort, tree.sort

    assert_equal 'Root', @root.path
    assert_equal 'Root::Outcome', @outcome.path

    assert_equal 4, @outcome.rev_index
    @outcome.new_index
    assert_equal 11, @outcome.rev_index
    @outcome.new_index
    assert_equal 12, @outcome.rev_index
    @outcome.name = 'Outcome2'
    assert_equal 13, @outcome.rev_index
    @outcome.name = 'Outcome'
    assert_equal 14, @outcome.rev_index

    foo = Users.create('foo', 'foo bar', 'foobar')
    box = Accounts.create('Cashbox', 'Running cash', @cash,
                          '5544436cf81115c6faf577a7e2307e92-7')

    assert_equal '1040.0', @cash.total
    @cash.set_nochildmult('Cash_2', 'All money', @root, 1, [foo.name])
    assert_equal 'Cash_2', @cash.name
    assert_equal 'All money', @cash.desc
    assert_equal 1, @cash.multiplier
    assert_equal(-1, box.multiplier)
    assert_equal(-1040.0, @cash.total)

    assert_equal([{:value => 20.0,
                   :desc => 'Restaurant',
                   :account_src_id => [4],
                   :revision => nil,
                   :account_dst_id => [2],
                   :global_id => '5544436cf81115c6faf577a7e2307e92-4',
                   :index => 4,
                   :rev_index => 4,
                   :id => 4},
                  {:value => 100.0,
                   :desc => 'Gift',
                   :account_src_id => [2],
                   :revision => nil,
                   :account_dst_id => [3],
                   :global_id => '5544436cf81115c6faf577a7e2307e92-2',
                   :index => 2,
                   :rev_index => 2,
                   :id => 2},
                  {:value => 40.0,
                   :desc => 'Train',
                   :account_src_id => [4],
                   :revision => nil,
                   :account_dst_id => [2],
                   :global_id => '5544436cf81115c6faf577a7e2307e92-3',
                   :index => 3,
                   :rev_index => 3,
                   :id => 3},
                  {:value => 1000.0,
                   :desc => 'Salary',
                   :account_src_id => [2],
                   :revision => nil,
                   :account_dst_id => [3],
                   :global_id => '5544436cf81115c6faf577a7e2307e92-1',
                   :index => 1,
                   :rev_index => 1,
                   :id => 1}],
                 @cash.movements.collect { |m| m.to_hash.delete_if { |k, v| k == :date
                 } })

    assert_equal "All money\r5544436cf81115c6faf577a7e2307e92-2\t-1040.000\t" +
                     "Cash_2\t1\t5544436cf81115c6faf577a7e2307e92-1\tfalse\tfalse",
                 @cash.to_s

    assert_equal false, @cash.is_empty
    box = Accounts.create('Cashbox', 'Running cash', @cash,
                          '5544436cf81115c6faf577a7e2307e92-8')
    assert_equal true, box.is_empty

    assert_equal(1, @cash.multiplier)
    assert_equal(1, box.multiplier)
    @cash.set_child_multiplier_total(-1, true)
    assert_equal(-1, @cash.multiplier)
    assert_equal(-1, box.multiplier)

    assert_equal 7, Accounts.search_all.length
    box.delete
    assert_equal 7, Accounts.search_all.length
    assert_equal true, box.deleted
  end

  def test_accounts
    assert_equal 2, @cash.id

    box = Accounts.create('Cashbox', 'Running cash', @cash,
                          '5544436cf81115c6faf577a7e2307e92-8')
    assert_equal({:multiplier => -1,
                  :desc => 'Running cash',
                  :total => 0,
                  :account_id => 2,
                  :global_id => '5544436cf81115c6faf577a7e2307e92-8',
                  :name => 'Cashbox',
                  :id => 6,
                  :deleted => false,
                  :keep_total => true,
                  :rev_index => 11}, box.to_hash)
    assert_equal 'Root::Cash::Cashbox', box.path
    assert_equal(-1, @cash.multiplier)
    assert_equal(-1, box.multiplier)

    box_s = box.to_s
    box.delete
    dputs(1) { "box_s is #{box_s.inspect}" }
    box = Accounts.from_s(box_s)
    assert_equal({:multiplier => -1.0,
                  :desc => 'Running cash',
                  :total => 0.0,
                  :account_id => 2,
                  :global_id => '5544436cf81115c6faf577a7e2307e92-8',
                  :name => 'Cashbox',
                  :id => 6,
                  :deleted => false,
                  :keep_total => true,
                  :rev_index => 21}, box.to_hash)

    course = Accounts.create_path('Root::Income::Course', 'course')
    assert_equal 'Root::Income::Course', course.get_path
    assert_equal '5544436cf81115c6faf577a7e2307e92-7', course.global_id

    ccard = Accounts.create_path('Credit::Card', 'credit-card')
    assert_equal 'Credit::Card', ccard.get_path
    assert_equal '5544436cf81115c6faf577a7e2307e92-9', ccard.global_id
  end

  def test_users
    Users.create('foo2', 'foo foo', 'foo2bar')
    foo = Users.match_by_name('foo2')
    assert_equal 'foo foo', foo.full
    assert_equal 'foo2bar', foo.pass
    assert_equal 0, foo.movement_index
    assert_equal 0, foo.account_index

    foo.update_movement_index
    assert_equal 4, foo.movement_index
    foo.update_account_index
    assert_equal 10, foo.account_index
  end

  def test_remote
    rem = Remotes.create(:url => 'http://localhost:3302/acaccount',
                         :name => 'foo', :pass => 'bar')
    assert_equal 0, rem.account_index
    assert_equal 0, rem.movement_index

    rem.update_movement_index
    assert_equal 4, rem.movement_index
    rem.update_account_index
    assert_equal 10, rem.account_index

    rem2 = Remotes.create(:url => 'http://localhost:3302/acaccount',
                          :name => 'foo', :pass => 'bar', :account_index => 10,
                          :movement_index => 20)
    assert_equal 10, rem2.account_index
    assert_equal 20, rem2.movement_index
  end

  def test_merge_get
    rep = ACaccess.get('version/foo,ba')
    assert_equal 'User foo not known with pass ba', rep

    rep = ACaccess.get('version/foo,bar')
    assert_equal $VERSION.to_s, rep

    rep = ACaccess.get('index/foo,bar')
    assert_equal '11,5', rep

    rep = ACaccess.get('accounts_get_one/5544436cf81115c6faf577a7e2307e92-2' +
                           '/foo,bar')
    assert_equal "Full description\r5544436cf81115c6faf577a7e2307e92-2\t" +
                     "1040.000\tCash\t-1\t5544436cf81115c6faf577a7e2307e92-1\tfalse\ttrue", rep

    rep = ACaccess.get('accounts_get/foo,bar')
    assert_equal "Full description\r5544436cf81115c6faf577a7e2307e92-1\t0.000\t" +
                     "Root\t1\t\tfalse\tfalse\n" +
                     "Full description\r5544436cf81115c6faf577a7e2307e92-2\t1040.000\t" +
                     "Cash\t-1\t5544436cf81115c6faf577a7e2307e92-1\tfalse\ttrue\n" +
                     "Full description\r5544436cf81115c6faf577a7e2307e92-3\t1100.000\t" +
                     "Income\t1\t5544436cf81115c6faf577a7e2307e92-1\tfalse\tfalse\n" +
                     "Full description\r5544436cf81115c6faf577a7e2307e92-5\t0.000\t" +
                     "Lending\t-1\t5544436cf81115c6faf577a7e2307e92-1\tfalse\ttrue\n" +
                     "Full description\r5544436cf81115c6faf577a7e2307e92-4\t-60.000\t" +
                     "Outcome\t1\t5544436cf81115c6faf577a7e2307e92-1\tfalse\tfalse", rep

    ACaccess.get('reset_user_account_indexes/foo,bar')
    rep = ACaccess.get('accounts_get/foo,bar')
    assert_equal '', rep

    rep = ACaccess.get('accounts_get_all/foo,bar')
    assert_equal "Full description\r5544436cf81115c6faf577a7e2307e92-1\t0.000\t" +
                     "Root\t1\t\tfalse\tfalse\tRoot\n" +
                     "Full description\r5544436cf81115c6faf577a7e2307e92-2\t1040.000\t" +
                     "Cash\t-1\t5544436cf81115c6faf577a7e2307e92-1\tfalse\ttrue\tRoot::Cash\n" +
                     "Full description\r5544436cf81115c6faf577a7e2307e92-3\t1100.000\t" +
                     "Income\t1\t5544436cf81115c6faf577a7e2307e92-1\tfalse\tfalse\tRoot::Income\n" +
                     "Full description\r5544436cf81115c6faf577a7e2307e92-4\t-60.000\t" +
                     "Outcome\t1\t5544436cf81115c6faf577a7e2307e92-1\tfalse\tfalse\tRoot::Outcome\n" +
                     "Full description\r5544436cf81115c6faf577a7e2307e92-5\t0.000\t" +
                     "Lending\t-1\t5544436cf81115c6faf577a7e2307e92-1\tfalse\ttrue\tRoot::Lending", rep

    rep = ACaccess.get('movements_get_one/5544436cf81115c6faf577a7e2307e92-4/foo,bar')
    assert_equal "Restaurant\r5544436cf81115c6faf577a7e2307e92-4\t20.000\t" +
                     "2012-07-11\t5544436cf81115c6faf577a7e2307e92-4\t" +
                     '5544436cf81115c6faf577a7e2307e92-2', rep

    rep = ACaccess.get('movements_get_all/0,100/foo,bar')
    assert_equal "Salary\r5544436cf81115c6faf577a7e2307e92-1\t1000.000\t" +
                     "2012-07-01\t5544436cf81115c6faf577a7e2307e92-2\t" +
                     "5544436cf81115c6faf577a7e2307e92-3\nGift\r" +
                     "5544436cf81115c6faf577a7e2307e92-2\t100.000\t2012-07-10\t" +
                     "5544436cf81115c6faf577a7e2307e92-2\t5544436cf81115c6faf577a7e2307e92-3\n" +
                     "Train\r5544436cf81115c6faf577a7e2307e92-3\t40.000\t2012-07-02\t" +
                     "5544436cf81115c6faf577a7e2307e92-4\t5544436cf81115c6faf577a7e2307e92-2\n" +
                     "Restaurant\r5544436cf81115c6faf577a7e2307e92-4\t20.000\t2012-07-11\t" +
                     "5544436cf81115c6faf577a7e2307e92-4\t5544436cf81115c6faf577a7e2307e92-2\n",
                 rep

    rep = ACaccess.get('movements_get/foo,bar')
    assert_equal "Salary\r5544436cf81115c6faf577a7e2307e92-1\t1000.000\t" +
                     "2012-07-01\t5544436cf81115c6faf577a7e2307e92-2\t" +
                     "5544436cf81115c6faf577a7e2307e92-3\nGift\r" +
                     "5544436cf81115c6faf577a7e2307e92-2\t100.000\t2012-07-10\t" +
                     "5544436cf81115c6faf577a7e2307e92-2\t5544436cf81115c6faf577a7e2307e92-3\n" +
                     "Train\r5544436cf81115c6faf577a7e2307e92-3\t40.000\t2012-07-02\t" +
                     "5544436cf81115c6faf577a7e2307e92-4\t5544436cf81115c6faf577a7e2307e92-2\n" +
                     "Restaurant\r5544436cf81115c6faf577a7e2307e92-4\t20.000\t2012-07-11\t" +
                     "5544436cf81115c6faf577a7e2307e92-4\t5544436cf81115c6faf577a7e2307e92-2\n",
                 rep

    ACaccess.get('reset_user_movement_indexes/foo,bar')
    rep = ACaccess.get('movements_get/foo,bar')
    assert_equal '', rep
  end

  def test_merge_post
    input = {'user' => 'foo', 'pass' => 'bar'}

    rep = ACaccess.post('account_get_id', input.merge('account' => 'Root'))
    assert_equal '1', rep
    rep = ACaccess.post('account_get_id', input.merge('account' => 'Root::Cash'))
    assert_equal '2', rep

    mov_pizza = "Pizza\r5544436cf81115c6faf577a7e2307e92-5\t12.0\t" +
        "2012-07-20\t5544436cf81115c6faf577a7e2307e92-4\t" +
        '5544436cf81115c6faf577a7e2307e92-2'
    mov_panini = "Panini\r5544436cf81115c6faf577a7e2307e92-6\t14.0\t" +
        "2012-07-21\t5544436cf81115c6faf577a7e2307e92-4\t" +
        '5544436cf81115c6faf577a7e2307e92-2'
    assert_equal '-60.0', @outcome.total
    assert_equal '1040.0', @cash.total
    rep = ACaccess.post('movements_put', input.merge('movements' =>
                                                         [{:str => mov_pizza}.to_json, {:str => mov_panini}.to_json].to_json))
    assert_equal 'ok', rep

    mov_pizza_merged = Movements.match_by_desc('Pizza')
    assert_equal 12.0, mov_pizza_merged.value
    mov_panini_merged = Movements.match_by_desc('Panini')
    assert_equal 14.0, mov_panini_merged.value
    assert_equal(-86.0, @outcome.total)
    assert_equal 1014.0, @cash.total
    Entities.Movements.save

    Entities.Movements.load
    mov_pizza_merged = Movements.match_by_desc('Pizza')
    assert_equal '2012-07-20', mov_pizza_merged.date.to_s
    mov_panini_merged = Movements.match_by_desc('Panini')
    assert_equal '2012-07-21', mov_panini_merged.date.to_s

    dputs(1) { 'Going to overwrite pizza and panini' }
    dputs(2) { "Movements are #{Movements.search_all.inspect}" }
    rep = ACaccess.post('movements_put', input.merge('movements' =>
                                                         [{:str => mov_pizza.sub('12.0', '22.0')}.to_json,
                                                          {:str => mov_panini.sub('14.0', '24.0')}.to_json].to_json))
    dputs(2) { "Movements are #{Movements.search_all.inspect}" }
    assert_equal 'ok', rep
    mov_pizza_merged = Movements.match_by_desc('Pizza')
    assert_equal 22.0, mov_pizza_merged.value, mov_pizza_merged.inspect
    mov_panini_merged = Movements.match_by_desc('Panini')
    assert_equal 24.0, mov_panini_merged.value, mov_panini_merged.inspect

  end

  # This is only relevant when testing with big data from solar
  def tes_gettree
    tree = []
    Accounts.matches_by_account_id(0).to_a.each { |a|
      a.get_tree { |b| tree.push b.rev_index }
    }
    tree_d = []
    Accounts.matches_by_account_id(0).to_a.each { |a|
      a.get_tree_debug { |b| tree_d.push b.rev_index }
    }

    assert_equal 389, tree.count
    assert_equal 389, tree_d.count
  end

  def setup_clean_accounts(loans = false)
    Entities.delete_all_data()
    Users.create('local', '123456789', 'bar')
    @root = Accounts.create('Root')
    @income = Accounts.create('Income', '', @root)
    @spending = Accounts.create('Spending', '', @root)
    @cash = Accounts.create('Cash', '', @root)
    @cash.multiplier = -1
    @cash.keep_total = true
    if loans
      @loan = Accounts.create('Loan', '', @cash)
      @loan.multiplier = 1
      @loan.keep_total = true
      @zcash = Accounts.create('ZCash', '', @cash)
      @zcash.multiplier = -1
      @zcash.keep_total = true
    end
  end

  def get_sorted_accounts(name)
    Accounts.search_by_name(name).sort {
        |a, b| a.path <=> b.path
    }
  end

  def test_archive
    setup_clean_accounts
    @base = []
    [1001, 1009, 1012, 1106, 1112, 1201].each { |b|
      #[ 1001, 1009 ].each{|b|
      @base[b] = Accounts.create "Base_#{b}", '', @income
    }

    def testmov(base, cash, years)
      d = 1
      years.each { |y|
        Movements.create("inscr #{base.desc}", "#{y}-01-2#{d}",
                         y.to_i + d, base, cash)
        d += 1
      }
    end

    # This should never happen, but still it's possible...
    Movements.create 'buggy', '2011-01-01', 100, @income, @cash

    # Create different test cases in different accounts
    # This has most == last == 2010
    testmov(@base[1001], @cash, %w( 2010 2010 ))
    # This has most == 2010, last == 2011
    testmov(@base[1009], @cash, %w( 2010 2010 2011 ))
    if true
      # This has most == last == 2011
      testmov(@base[1012], @cash, %w( 2010 2011 2011 ))
      # This has most == 2011, last == 2012
      testmov(@base[1106], @cash, %w( 2011 2011 2012 ))
      # This has most == last == 2012 and movements in 2011
      testmov(@base[1112], @cash, %w( 2011 2012 2012 ))
      # This has most == last == 2012 and no movements in 2011
      testmov(@base[1201], @cash, %w( 2012 2012 ))
    end

    Accounts.archive(1, 2012)

    # Name, account-count, movs-count, path of first occurence
    [[1001, 1, 2, 'Archive::2010::Income::Base_1001'],
     [1009, 3, 2, 'Archive::2010::Income::Base_1009'],
     [1012, 3, 1, 'Archive::2010::Income::Base_1012'],
     [1106, 2, 2, 'Archive::2011::Income::Base_1106'],
     [1112, 2, 1, 'Archive::2011::Income::Base_1112'],
     [1201, 1, 2, 'Root::Income::Base_1201']
    ].each { |b|
      name, count, movs, path = b
      accs = get_sorted_accounts("Base_#{name}")
      dputs(3) { "Accounts are #{accs.collect { |a| a.path }.join('-')  }" }
      assert_equal count, accs.count, "Count for #{name}"
      assert_equal movs, accs.first.movements.count, "movs for #{name}"
      assert_equal path, accs.first.path, "path for #{name}"
    }
  end

  def add_movs
    Movements.create('Year 2010', '2011-01-01', 10, @cash, @income)
    Movements.create('Year 2011', '2012-05-01', 20, @cash, @income)
    Movements.create('Year 2012', '2012-06-01', 30, @cash, @income)
  end

  def test_archive_start_june
    setup_clean_accounts
    add_movs
    Accounts.archive(6, 2012)
    incomes = get_sorted_accounts('Income')
    cash = get_sorted_accounts('cash')

    assert_equal 3, incomes.length
    assert_equal 1, incomes[0].movements.length
    assert_equal 1, incomes[1].movements.length
    assert_equal 1, incomes[2].movements.length

    assert_equal 3, cash.length
    assert_equal 1, cash[0].movements.length
    assert_equal 2, cash[1].movements.length
    assert_equal 2, cash[2].movements.length
  end

  # Testing keep_total true and false
  def test_archive_multiple_invocations
    setup_clean_accounts
    add_movs
    Accounts.archive(6, 2012)
    incomes = get_sorted_accounts('Income')
    cash = get_sorted_accounts('cash')

    assert_equal 3, incomes.length
    assert_equal 1, incomes[0].movements.length
    assert_equal 1, incomes[1].movements.length
    assert_equal 1, incomes[2].movements.length
    cash.each { |a|
      dputs(1) { "#{a.path} - #{a.movements.length}" }
    }
    assert_equal 3, cash.length
    assert_equal 1, cash[0].movements.length
    assert_equal 2, cash[1].movements.length
    assert_equal 2, cash[2].movements.length

    Accounts.archive(6, 2012)
    incomes = get_sorted_accounts('Income')
    cash = get_sorted_accounts('cash')

    assert_equal 3, incomes.length
    assert_equal 1, incomes[0].movements.length
    assert_equal 1, incomes[1].movements.length
    assert_equal 1, incomes[2].movements.length
    cash.each { |a|
      dputs(1) { "#{a.path} - #{a.movements.length}" }
    }
    assert_equal 3, cash.length
    assert_equal 1, cash[0].movements.length
    assert_equal 2, cash[1].movements.length
    assert_equal 2, cash[2].movements.length
  end

  def test_archive_sum_up
    # Make sure that everything still sums up
    setup_clean_accounts
    assert_equal(0, Accounts.match_by_name('Spending').total)
    add_movs
    assert_equal(0, Accounts.match_by_name('Spending').total)
    Movements.create('Year 2012 - 1', '2012-06-01', 20, @spending, @cash)

    assert_equal(-20, Accounts.match_by_name('Spending').total)
    assert_equal(40, Accounts.match_by_name('Cash').total)
    @cash.update_total
    assert_equal(40, Accounts.match_by_name('Cash').total)

    dputs(2) { '**** - Archiving for 2012 - *****' }
    Accounts.archive(6, 2012)
    cashs = get_sorted_accounts('Cash')
    (0..2).each { |i|
      dputs(3) { "Path for #{i} is #{cashs[i].get_path}" }
    }
    assert_equal 10, cashs[0].total
    assert_equal 30, cashs[1].total
    assert_equal 40, cashs[2].total
  end

  def test_archive_sum_up_consecutive
    # Test two consecutive runs on the archive like 2013, then 2014, and
    # make sure that the accounts that hold only a "final"-movement get
    # deleted
    setup_clean_accounts
    add_movs
    Movements.create('Year 2012 - 1', '2012-06-01', -30, @cash, @spending)
    Accounts.dump(true)

    dputs(1) { '**** - Archiving 1st for 2013 - *****' }
    Accounts.archive(6, 2013)
    Accounts.dump(true)
    incomes = get_sorted_accounts('Income')
    cash = get_sorted_accounts('Cash')
    assert_equal 4, incomes.count
    assert_equal 0, incomes[3].total
    assert_equal 30, incomes[2].total, incomes[2].inspect
    assert_equal 4, cash.count
    assert_equal 30, cash[3].total
    # check also after re-calculating of the totals!
    incomes[3].update_total
    assert_equal 0, incomes[3].total
    cash[3].update_total
    assert_equal 30, cash[3].total

    dputs(1) { '**** - Archiving 2nd for 2014 - *****' }
    # @cash and @spending are now pointing to the archived ones...
    cash = Accounts.get_by_path('Root::Cash')
    spending = Accounts.get_by_path('Root::Spending')
    Movements.create('Year 2013 - 2', '2013-06-01', -30, cash, spending)
    Accounts.archive(6, 2014)
    Accounts.dump(true)

    incomes = get_sorted_accounts('Income')
    dputs(3) { incomes.inspect }
    cash = get_sorted_accounts('Income')
    dputs(3) { cash.inspect }
    # We lost the actual account, as it should be empty
    assert_equal 4, incomes.count
    assert_equal true, incomes[3].deleted
    assert_equal 30, incomes[2].total, incomes[2].inspect
    assert_equal 4, cash.count
    assert_equal 30, cash[2].total, cash[2].inspect

    spending = get_sorted_accounts('Spending')
    assert_equal 3, spending.count
    assert_equal(0, spending[2].total)
  end

  def test_creation
    Entities.delete_all_data()
    ACQooxView::check_db
  end

  def load_big_data
    dputs(1) { 'Setting up big data' }
    Entities.delete_all_data()

    dputs(2) { 'Resetting SQLite' }
    SQLite.dbs_close_all
    dputs(2) { 'Loading big data' }
    FileUtils.cp('db.solar', 'data/compta.db')
    SQLite.dbs_open_load_migrate
  end

  def test_big_data_archive
    TESTBIG or return

    require 'benchmark'
    require 'perftools'
    load_big_data
    Accounts.archive(1, 2012)
  end

  def test_big_data_merge
    TESTBIG or return

    require 'benchmark'
    require 'perftools'
    load_big_data

    ACaccess.get('reset_user_indexes/ineiti,lasj')
    dputs(1) { Benchmark.measure {
      PerfTools::CpuProfiler.start('perfcheck_merge_1st') do
        ACaccess.get('accounts_get/ineiti,lasj')
      end
    }.to_s
    }
    dputs(1) { Benchmark.measure {
      PerfTools::CpuProfiler.start('perfcheck_merge_2nd') do
        ACaccess.get('accounts_get/ineiti,lasj')
      end
    }.to_s
    }
    puts 'Now run
pprof.rb --pdf perfcheck_merge_1st > perfcheck_merge_1st.pdf
pprof.rb --pdf perfcheck_merge_2nd > perfcheck_merge_2nd.pdf
open perfcheck_merge_1st.pdf perfcheck_merge_2nd.pdf
    '
  end

  def test_big_data_check
    TESTBIG or return

    load_big_data

    ACaccess.get('reset_user_indexes/ineiti,lasj')
    dputs(1) { Benchmark.measure {
      ACaccess.get('movements_get_all/1,10000/ineiti,lasj')
    }.to_s
    }
    dputs(1) { Benchmark.measure {
      ACaccess.get('movements_get_all/1,10000/ineiti,lasj')
    }.to_s
    }
  end

  def test_archive_2
    TESTBIG or return

    load_big_data
    Accounts.archive(1, 2012,
                     Accounts.get_by_path('Root::Caisses::Centre::Josué'))
  end

  def test_archive_3
    TESTBIG or return

    load_big_data
    Accounts.archive(1, 2012,
                     Accounts.get_by_path('Root::Caisses::Centre::Rubia Centre'))
  end

  def test_archive_negative
    setup_clean_accounts true

    mov = Movements.create 'lending', '2013-01-01', 100, @loan, @income
    Movements.create 'lending 2', '2013-01-01', 100, @zcash, @income

    assert_equal -100, @loan.total
    assert_equal @loan, mov.account_src
    assert_equal 1, @loan.multiplier
    Accounts.archive

    @loan_2013 = Accounts.get_by_path('Archive::2013::Cash::Loan')
    assert @loan_2013
    assert_equal -100, @loan_2013.total
    assert_equal 1, @loan_2013.multiplier
    mov = Movements.find_by_desc 'lending'
    assert_equal @loan_2013, mov.account_src
  end

  def test_archive_negative_2
    setup_clean_accounts true

    mov = Movements.create 'lending', '2013-01-01', 100, @loan, @zcash

    assert_equal -100, @loan.total
    assert_equal 1, @loan.multiplier
    assert_equal @loan, mov.account_src
    Accounts.archive

    @loan_2013 = Accounts.get_by_path('Archive::2013::Cash::Loan')
    assert @loan_2013
    assert_equal -100, @loan_2013.total
    assert_equal 1, @loan_2013.multiplier
    mov = Movements.find_by_desc 'lending'
    assert_equal @loan_2013, mov.account_src
  end

  def test_archive_negative_3
    setup_clean_accounts true

    mov = Movements.create 'lending', '2013-01-01', 100, @loan, @zcash

    assert_equal -100, @loan.total
    assert_equal 1, @loan.multiplier
    assert_equal @loan, mov.account_src
    Accounts.archive

    @loan_2013 = Accounts.get_by_path('Archive::2013::Cash::Loan')
    assert @loan_2013
    assert_equal -100, @loan_2013.total
    assert_equal 1, @loan_2013.multiplier
    mov = Movements.find_by_desc 'lending'
    assert_equal @loan_2013, mov.account_src
  end

  def test_archive_keep_root
    setup_clean_accounts
    Accounts.archive
    Accounts.dump_raw

    assert root = Accounts.get_by_path('Root')
    assert_not_equal true, root.deleted
  end

  def test_archive_negative_4
    setup_clean_accounts true
    Movements.create 'lending 2012-1', '2012-02-02', 100, @loan, @income
    Movements.create 'lending 2012-2', '2012-02-02', 100, @loan, @outcome

    assert_equal -200, @loan.total
    Accounts.archive(1, 2013)

    assert income = Accounts.get_by_path('Root::Income')
    assert loan = Accounts.get_by_path('Root::Cash::Loan')

    mov = Movements.create 'lending 2013-1', '2013-02-02', 100, loan, income
    mov = Movements.create 'lending 2013-2', '2013-02-02', 100, income, loan
    Accounts.archive(1, 2014)

    archive_2012 = Accounts.get_by_path('Archive::2012')
    assert_equal 2, archive_2012.movements.length
  end

  def tes_archive_profeda
    Entities.delete_all_data()
    SQLite.dbs_close_all
    FileUtils.cp('db.profeda', 'data/compta.db')
    MigrationVersions.create(:class_name => 'Account', :version => 1)
    SQLite.dbs_open_load_migrate

    assert avance = Accounts.find_by_name('Avance maintenance')
    #avance.dump true
    dputs(1) { 'Before archiving: ' }
    #Accounts.get_by_path( "Archive::2012" ).dump true
    #Accounts.dump
    assert_equal 1, avance.multiplier

    Accounts.archive
    dputs(1) { 'After archiving: ' }
    assert archive_2012 = Accounts.get_by_path('Archive::2012')
    archive_2012.dump true
    #Accounts.dump
  end

  def test_get_by_path
    cash = Accounts.get_by_path('Root::Cash')

    assert_equal 'Cash', cash.name
  end

  dputs(0) { 'Disabled test_speed' }

  def tes_speed
    require 'rubygems'
    require 'perftools'
    PerfTools::CpuProfiler.start('/tmp/profile') do
      (2010..2012).each { |year|
        dputs(1) { "Doing year #{year}" }
        (1..12).each { |month|
          (1..10).each { |day|
            (1..1).each { |t|
              date = "#{year}-#{month}-#{day}"
              Movements.create("Test #{date}", date, t, @cash, @income)
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
    assert_equal 2.6, a.round(1)
    assert_equal 2.56, a.round(2)
  end

  def test_create_path
    accounts = Accounts.search_all.size

    base1 = Accounts.create_path('Root::Income::Base', 'base')
    assert_equal accounts + 1, Accounts.search_all.size

    base2 = Accounts.create_path('Root::Income::Base', 'base')
    assert_equal accounts + 1, Accounts.search_all.size
    assert_equal base1, base2

    base3 = Accounts.create_path('Root::Income::Base', 'base', true)
    assert_equal accounts + 2, Accounts.search_all.size
    assert_not_equal base1, base3

    credit = Accounts.create_path('Credit::Card', 'mastercard')
    assert_equal 'Credit::Card', credit.path
  end
end

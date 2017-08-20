require 'test/unit'

class TC_Movement < Test::Unit::TestCase
  def setup
    dputs(1) { 'Setting up new data' }
    Entities.delete_all_data()

    dputs(2) { 'Resetting SQLite' }
    SQLite.dbs_close_all
    FileUtils.cp('db.testGestion', 'data2/compta.db')
    SQLite.dbs_open_load_migrate

    dputs(2) { 'And searching for some accounts' }
    @root = Accounts.match_by_name('Root')
    @cash = Accounts.match_by_name('Cash')
    @lending = Accounts.match_by_name('Lending')
    @income = Accounts.match_by_name('Income')
    @outcome = Accounts.match_by_name('Outcome')
    @local = Users.match_by_name('local')

    @user_1 = Users.create('user1', '', 'pass')
    @user_2 = Users.create('user2', '', 'pass')
  end

  def teardown
  end

  def test_rm_add
    m = Movements.create('test', Date.today, 1000, @cash, @lending)
    m.delete
    Movements.create('test', Date.today, 1000, @cash, @lending)
    assert_equal 2040, @cash.total.to_i
  end

  def test_move
    value_cash = @cash.total.to_f
    value_lending = @lending.total.to_f
    value_income = @income.total.to_f
    m = Movements.create('test', Date.today, 1000, @cash, @lending)
    assert_equal @cash, m.account_src
    assert_equal @lending, m.account_dst
    assert_equal value_cash + 1000, @cash.total.to_f
    assert_equal value_lending - 1000, @lending.total.to_f

    m.move_from_to(@cash, @income)
    assert_equal @income, m.account_src
    assert_equal @lending, m.account_dst
    assert_equal value_cash, @cash.total.to_f
    assert_equal value_income - 1000, @income.total.to_f
    assert_equal value_lending - 1000, @lending.total.to_f

    m.move_from_to(@lending, @cash)
    assert_equal @income, m.account_src
    assert_equal @cash, m.account_dst
    assert_equal value_cash - 1000, @cash.total.to_f
    assert_equal value_income - 1000, @income.total.to_f
    assert_equal value_lending, @lending.total.to_f
  end

  def test_search_index
    res = Movements.search_index_range(2, 3)
    assert_equal 2, res.length
    assert_equal Movement, res.first.class
    assert_equal [2, 3], res.map { |m| m.rev_index }
  end

  def test_date
    Movements.create('newmov', '2015-01-02', 100, @income, @cash)
    Entities.reload
    assert_equal Date, Movements.find_by_desc('newmov').date.class

    Entities.delete_all_data
    Entities.load_all
    Movements.create('newmov', '2015-01-02', 100, @income, @cash)
    Entities.reload

    assert_equal Date, Movements.find_by_desc('newmov').date.class
  end
end

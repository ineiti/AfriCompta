require 'test/unit'

class TC_Merge < Test::Unit::TestCase
  def setup
    dputs(1) { 'Setting up new data' }

    Entities.delete_all_data()
    Entities.Accounts.load

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
    Entities.save_all
  end

  def test_path
    assert_equal 'Root::Cash', @cash.path
  end

  def test_send_account

  end

end

require 'test/unit'

class TC_Account < Test::Unit::TestCase
  def setup
    dputs(1) { 'Setting up new data'
    }
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
    Entities.save_all
  end

  def test_path
    assert_equal 'Root::Cash', @cash.path
    assert_equal 0, @root.account_id
    assert_equal nil, @root.account
  end

  def test_del_account
    AccountRoot.accounts.each { |a|
      dputs(1) { "Found root-account #{a.inspect}" }
      a.get_tree { |t|
        dputs(1) {
          "#{t.path} - #{t.deleted.inspect}"
        }
      }
    }
    assert_equal false, @root.delete, @root.inspect
    assert_equal false, @income.delete
    old_index = @lending.rev_index
    assert_equal true, @lending.delete
    assert_operator old_index, :<, @lending.rev_index

    Accounts.create_path('Root::Cash::Foo', '')
  end

  def test_account_root
    Accounts.create_path('Root::Archive')
    assert_equal nil, AccountRoot.archive

    Accounts.create_path('Archive')
    assert_not_equal nil, AccountRoot.archive
  end

  def test_clean
    Accounts.create_path('Test')
    Accounts.dump true
    count_mov, bad_mov, count_acc, bad_acc = AccountRoot.clean
    assert_equal [4, 0, 18, 1],
                 [count_mov, bad_mov, count_acc, bad_acc]

    Accounts.dump
    count_mov, bad_mov, count_acc, bad_acc = AccountRoot.clean
    assert_equal [4, 0, 18, 0],
                 [count_mov, bad_mov, count_acc, bad_acc]
  end

  def test_merge_two_users
    @user_1.update_all
    @u1 = {'user' => 'user1', 'pass' => 'pass'}
    @user_2.update_all
    @u2 = {'user' => 'user2', 'pass' => 'pass'}

    a_id = ACaccess.post('account_get_id', @u1.merge('account' => 'Root'))
    assert_equal '1', a_id

    assert_equal '', ACaccess.get('accounts_get/user1,pass')
    assert_equal '', ACaccess.get('accounts_get/user2,pass')
  end

  def test_merge_account_delete
    test_merge_two_users

    @lending.delete
    dputs(3) { @lending.inspect }
    ACaccess.post('account_put', @u1.merge('account' => @lending.to_s))
    assert_equal '', ACaccess.get('accounts_get/user1,pass')
    assert_equal @lending.to_s, ACaccess.get('accounts_get/user2,pass').chomp
  end

  def test_merge_account_change
    test_merge_two_users

    @lending.name = 'Lendings'
    @lending.new_index
    dputs(3) { @lending.inspect }
    ACaccess.post('account_put', @u1.merge('account' => @lending.to_s))
    assert_equal '', ACaccess.get('accounts_get/user1,pass')
    assert_equal @lending.to_s, ACaccess.get('accounts_get/user2,pass').chomp

    assert_equal 1, @lending.account_id
  end

  def test_print_pdf
    @root.print_pdf('test.pdf', true)
  end

  def test_get_archives
    (2011..2014).each { |y|
      Movements.create('', Date.new(y), 1000, @income, @cash)
    }
    Movements.create('', Date.new(2013, 3, 3), 1000, @outcome, @cash)
    Accounts.archive(1, 2014)

    assert_equal %w(Archive::2011::Income Archive::2012::Income Archive::2013::Income),
                 Accounts.get_by_path('Root::Income').get_archives.collect { |a|
                   a.path }.sort
    assert_equal %w(Archive::2012::Outcome Archive::2013::Outcome),
                 Accounts.get_by_path('Root::Outcome').get_archives.collect { |a|
                   a.path }.sort
  end

  def test_delete
    acc = Accounts.create('newaccount', '', @cash)
    assert acc.rev_index > 0
    rindex = acc.rev_index
    acc.delete
    assert acc.rev_index > rindex
  end

  def test_report
    date = Date.today

    # Make a tree with depth two of accounts with movements inside
    accs = Array.new(3) { Array.new(3) }
    [1, 2].each { |src|
      accs[src][0] = Accounts.create("src_#{src}", nil, @income)
      [1, 2, 3].each { |sub|
        accs[src][sub] = Accounts.create("sub_#{src}_#{sub}", nil, accs[src][0])
        [1, 2, 3].each { |mov|
          Movements.create("Mov for #{src}_#{sub} - #{mov}", date, 100 * src,
                           accs[src][sub], @cash)
        }
        assert_equal( -300 * src, accs[src][sub].total)
      }
    }

    reportAccount = ReportAccounts.create(account: @income, level: 1)
    report = Reports.create(name: 'test', accounts: [reportAccount])

    line = report.print_account_monthly(reportAccount, date, 1, 1)
    dp line
  end

  def tes_report_man
    SQLite.dbs_close_all
    FileUtils.cp('db.man', 'data2/compta.db')
    SQLite.dbs_open_load
    dputs(0) { 'Finished loading' }
    #Accounts.search_all_.each{|acc|dp acc.path}
    AccountRoot.actual.dump
    entry = Accounts.get_by_path('Root::SaS::MaN Repos II::Entrés')
    assert_not_nil entry

    reportAccount = ReportAccounts.create(account: entry, level: 1)
    report = Reports.create(name: 'test', accounts: [reportAccount])

    line = report.print_account_monthly(reportAccount, Date.new(2014, 6), 1, 1)
    dp line
  end

  def test_add_account
    subacc = Accounts.create_path("Root::Test")
    Entities.reload
    assert_equal 6, Accounts.search_all_.count
  end
end

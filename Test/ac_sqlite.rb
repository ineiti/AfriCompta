require 'test/unit'
require 'sqlite3'

class TC_SQLite < Test::Unit::TestCase
  def setup
    Entities.delete_all_data()
    SQLite.dbs_close_all
    FileUtils.cp('db.testGestion', 'data/compta.db')
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

  def test_check_accounts
    Entities.delete_all_data
    Entities.load_all

    tmpfile = '/tmp/compta.db'
    tmpfile2 = '/tmp/compta2.db'

    FileUtils.cp('data/compta.db', tmpfile)
    in_db, diff, in_local = Accounts.check_against_db(tmpfile)
    dputs(3) { "#{in_db.inspect}\n#{diff.inspect}\n#{in_local.inspect}" }
    assert_equal [], in_db
    assert_equal [], diff
    assert_equal [], in_local

    Accounts.create('Services', '', Accounts.match_by_name('Income'))
    in_db, diff, in_local = Accounts.check_against_db(tmpfile)
    dputs(3) { "#{in_db.inspect}\n#{diff.inspect}\n#{in_local.inspect}" }
    assert_equal [], in_db
    assert_equal [], diff
    assert_equal Accounts.match_by_name('Services').to_s.to_a,
                 in_local

    Accounts.save
    FileUtils.cp('data/compta.db', tmpfile2)
    Accounts.match_by_name('Lending').name = 'Prêts'
    in_db, diff, in_local = Accounts.check_against_db(tmpfile2)
    dputs(3) { "#{in_db.inspect}\n#{diff.inspect}\n#{in_local.inspect}" }
    assert_equal [], in_db
    assert_equal 1, diff.length
    assert_equal [], in_local

    Accounts.delete_all
    Accounts.storage[:SQLiteAC].close_db
    FileUtils.cp(tmpfile, 'data/compta.db')
    SQLite.dbs_open_load_migrate
    in_db, diff, in_local = Accounts.check_against_db(tmpfile2)
    dputs(3) { "#{in_db.inspect}\n#{diff.inspect}\n#{in_local.inspect}" }
    assert_equal [Accounts.create('Services', '', Accounts.match_by_name('Income')).to_s],
                 in_db
    assert_equal 0, diff.length
    assert_equal [], in_local
  end

  def add_mov(desc, value, src, dst)
    Movements.create(desc, Date.today, value.to_f,
                     Accounts.match_by_name(src), Accounts.match_by_name(dst))
  end

  def add_movements
    [
        %w( Income Cash course1 10),
        %w( Income Cash course2 20),
        %w( Income Cash course3 30),
        %w( Cash Outcome salary1 25),
        %w( Cash Outcome salary2 15),
    ].each { |src, dst, desc, value|
      add_mov desc, value, src, dst
    }
  end

  def test_check_movements
    Entities.delete_all_data()
    Entities.load_all

    add_movements
    Movements.save
    tmpfile = '/tmp/compta.db'
    tmpfile2 = '/tmp/compta2.db'

    FileUtils.cp('data/compta.db', tmpfile)
    in_db, diff, in_local = Movements.check_against_db(tmpfile)
    dputs(3) { "#{in_db.inspect}\n#{diff.inspect}\n#{in_local.inspect}" }
    assert_equal [], in_db
    assert_equal [], diff
    assert_equal [], in_local

    add_mov 'Services', 20, 'Income', 'Cash'
    in_db, diff, in_local = Movements.check_against_db(tmpfile)
    dputs(3) { "#{in_db.inspect}\n#{diff.inspect}\n#{in_local.inspect}" }
    assert_equal [], in_db
    assert_equal [], diff
    assert_equal Movements.match_by_desc('Services').to_s.to_a,
                 in_local

    add_mov 'Services2', 20, 'Income', 'Cash'
    Movements.match_by_desc('Services2').delete
    Movements.save
    FileUtils.cp('data/compta.db', tmpfile2)
    in_db, diff, in_local = Movements.check_against_db(tmpfile2)
    dputs(3) { "#{in_db.inspect}\n#{diff.inspect}\n#{in_local.inspect}" }
    assert_equal [], in_db
    assert_equal [], diff
    assert_equal [], in_local

    Movements.save
    FileUtils.cp('data/compta.db', tmpfile2)
    Movements.match_by_desc('Services').desc = 'Prêts'
    in_db, diff, in_local = Movements.check_against_db(tmpfile2)
    dputs(3) { "#{in_db.inspect}\n#{diff.inspect}\n#{in_local.inspect}" }
    assert_equal [], in_db
    assert_equal 1, diff.length
    assert_equal [], in_local

    Movements.delete_all
    Movements.storage[:SQLiteAC].close_db
    FileUtils.cp(tmpfile, 'data/compta.db')
    SQLite.dbs_open_load_migrate
    in_db, diff, in_local = Movements.check_against_db(tmpfile2)
    dputs(3) { "#{in_db.inspect}\n#{diff.inspect}\n#{in_local.inspect}" }
    assert_equal [add_mov('Services', 20, 'Income', 'Cash').to_s], in_db
    assert_equal 0, diff.length
    assert_equal [], in_local
  end
end

require 'test/unit'

TESTBIG=false

class TC_Big < Test::Unit::TestCase
  def setup
    setup_db
  end

  def teardown
    Entities.save_all
  end

  def setup_db
    dputs_func
    dputs(1) { 'Setting up big data' }
    Entities.delete_all_data()

    dputs(2) { 'Resetting SQLite' }
    SQLite.dbs_close_all
    dputs(2) { 'Loading big data' }
    MigrationVersions.create({:class_name => 'Account', :version => 2})
    MigrationVersions.create({:class_name => 'Movement', :version => 1})
    MigrationVersions.save
    FileUtils.cp('db.man', 'data/compta.db')
    SQLite.dbs_open_load_migrate
    dputs(2) { 'Finished loading' }
    Entities.save_all
    @user = Users.match_by_name('local')
  end

  def reload_all
    Entities.delete_all_data(true)
    Entities.load_all
  end

  def test_matches_speed_improved
    dputs_func
    require 'benchmark'

    ret = ''
    dputs(1){ @user.account_index}
    dputs(1) { Benchmark.measure {
      ret = Accounts.data.select { |k, v|
        v._rev_index > 14000 }.
          collect { |k, v| Accounts.get_data_instance(k) }.
          sort_by { |a| a.path }.reverse.
          collect { |a| a.to_s }.
          join("\n")
    }.to_s
    }
    dputs(1){ ret.length}
  end

  def test_matches_speed_old
    dputs_func
    dputs(1) { Benchmark.measure {
      ACaccess.accounts_fetch(@user)
    }.to_s
    }
  end
end
require 'test/unit'

class TC_AfriCompta < Test::Unit::TestCase
  def setup
    dputs(0){"Setting up"}
    Entities.delete_all_data()

    dputs(0){"Resetting SQLite"}
    SQLite.dbs_close_all
    FileUtils.cp( "db.testGestion", "data/compta.db" )
    SQLite.dbs_open_load_migrate
    
    dputs(0){"And searching for some accounts"}
    @root = Accounts.find_by_name( "Root" )
    @cash = Accounts.find_by_name( "Cash" )
    @lending = Accounts.find_by_name( "Lending" )
    @income = Accounts.find_by_name( "Income" )
    @outcome = Accounts.find_by_name( "Outcome" )
    @local = Users.find_by_name( 'local' )
  end

  def teardown
  end

  def test_del_account
    AccountRoot.accounts.each{|a|
      a.get_tree{|t|
        dputs(0){
          "#{t.path} - #{t.deleted.inspect}"
        }
      }
    }
    assert_equal nil, @root.delete
    assert_equal nil, @income.delete
    old_index = @lending.index
    assert_equal true, @lending.delete
    assert_operator old_index, :<, @lending.index
    
    Accounts.create_path("Root::Cash::Foo", "")
  end
end

require 'test/unit'

class TC_AfriCompta < Test::Unit::TestCase
  def send_to_sqlite_users( m )
    Entities.Movements.send( m.to_sym )
    Entities.Accounts.send( m.to_sym )
    Entities.Users.send( m.to_sym )
  end
  
  def setup
    dputs(0){"Setting up"}
    Entities.delete_all_data()

    dputs(0){"Resetting SQLite"}
    send_to_sqlite_users :close_db
    FileUtils.cp( "db.testGestion", "data/compta.db" )
    send_to_sqlite_users :open_db
    send_to_sqlite_users :load
    RPCQooxdooService.migrate_all
    
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
  end
end

require 'test/unit'
require 'net/http'

class TC_Merge < Test::Unit::TestCase
  def setup
    dputs(1) { 'Setting up new data' }

    Entities.delete_all_data()

    dputs(1) { 'Closing all' }
    SQLite.dbs_close_all
    FileUtils.rm_f('data2/compta.db')
    start_other
    FileUtils.cp('thread1/data/compta.db', 'data2/compta.db')
    dputs(1) { 'Loading and migrating' }
    SQLite.dbs_open_load_migrate

    # Re-create the local user to get a new random id
    Users.reset_id

    #Entities.Accounts.load

    dputs(2) { 'And searching for some accounts' }
    @root = Accounts.match_by_name('Root')
    @cash = Accounts.match_by_name('Cash')
    @lending = Accounts.match_by_name('Lending')
    @income = Accounts.match_by_name('Income')
    @outcome = Accounts.match_by_name('Outcome')
    @local = Users.match_by_name('local')
    @remote = Remotes.create(url: 'http://localhost:3303/acaccess', name: 'other',
                             pass: 'other')

    @user_1 = Users.create('user1', '', 'pass')
    @user_2 = Users.create('user2', '', 'pass')
  end

  def teardown
    Entities.save_all
    if @other
      dputs(3) { "Killing #{@other}" }
      Process.kill(9, @other)
      Process.wait
      dputs(3) { "Joined #{@other}" }
    end
  end

  def test_path
    assert_equal 'Root::Cash', @cash.path
  end

  def start_other(wait=true)
    dir = 'thread1'
    FileUtils.rm_rf(dir)
    FileUtils.mkdir(dir)
    FileUtils.cp('other.rb', dir)
    FileUtils.cp('other.conf', dir)
    @other = Process.spawn('./other.rb')

    while wait
      begin
        Net::HTTP.get(URI('http://localhost:3303/acaccess'))
        return
      rescue Errno::ECONNREFUSED
        dputs(3) { 'Waiting on -other-' }
        sleep 0.5
      end
    end
  end

  def post_form(path, hash)
    dputs(4) { "postForm with path #{path}" }
    Net::HTTP.post_form(URI.parse(@remote.url + "/merge/#{path}"),
                        {'user' => @remote.name, 'pass' => @remote.pass}.merge(hash))
  end

  def get_form(path)
    url = URI.parse(@remote.url)
    dputs(4) { "Starting getForm with path #{path} - #{url.inspect}" }
    Net::HTTP.get(url.host, "#{url.path}/merge/#{path}/#{@remote.name},#{@remote.pass}", url.port)
  end

  def test_start_other
    assert Net::HTTP.get(URI('http://localhost:3303'))
  end

  def test_remote
    @remote.check_version
  end

  def test_copied
    assert_equal 4, get_form('accounts_get').split("\n").count
    @remote.do_copied
    assert_equal '5,0', get_form('index')
    assert_equal 0, get_form('accounts_get').split("\n").count
  end

  def test_check_versions
    assert @remote.check_version
    oldversion = $VERSION
    $VERSION = 0
    assert_raise RuntimeError do
      @remote.check_version
    end
    $VERSION = oldversion
  end

  def print_remote_accounts
    get_form('accounts_get_all').split("\n").each { |a| p a }
  end

  def print_accounts
    Accounts.search_all.each{|a| p a.to_s}
  end

  def test_get_remote_accounts
    #p Accounts.search_all.last.to_s
    @remote.do_copied
    post_form('account_put',
              account: "Initialisation\r27d1cfc78ed2ae03109b8963707b18f2-10\t"+
                  "0.000\tNewAccount\t1\t#{AccountRoot.current.global_id}\tfalse\tfalse",
              debug: true)
    assert_equal 0, Accounts.search_by_name('NewAccount').count
    @remote.get_remote_accounts
    assert_equal 1, Accounts.search_by_name('NewAccount').count
  end

  def test_send_accounts
    @remote.do_copied

    Accounts.create('Salaries', 'salaries', @outcome)
    remote_count = get_form('accounts_get_all').split("\n").count
    @remote.setup_instance
    @remote.send_accounts
    assert_equal remote_count + 1,
                 get_form('accounts_get_all').split("\n").count
    assert_equal 0, get_form('accounts_get').split("\n").count
  end

end

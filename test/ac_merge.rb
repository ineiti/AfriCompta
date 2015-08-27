require 'test/unit'
require 'net/http'

class TC_Merge < Test::Unit::TestCase
  def setup
    dputs(1) { 'Setting up new data' }

    Entities.delete_all_data()

    dputs(1) { 'Closing all' }
    SQLite.dbs_close_all
    FileUtils.rm_f('data2/compta.db')
    dputs(1) { 'Loading and migrating' }
    SQLite.dbs_open_load_migrate

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
    start_other
    assert Net::HTTP.get(URI('http://localhost:3303'))
  end

  def test_remote
    start_other
    @remote.check_version
  end

  def test_copied
    start_other
    assert_equal 4, get_form('accounts_get').split("\n").count
    @remote.do_copied
    assert_equal '5,0', get_form('index')
    assert_equal 0, get_form('accounts_get').split("\n").count
  end

  def test_send_account
    start_other
    other_accounts =
        Accounts.create('Salaries', 'salaries', @outcome)
  end

end

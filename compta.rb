# System libraries
require 'rubygems'
require 'camping'
#require 'camping/db'
require 'net/http'
require 'markaby'
require 'digest/md5'

# 4bits for each version: major-minor-revision-patch
# Patch is usually not needed.
$VERSION=0x1010

Camping.goes :Compta
# Have some nice HTML-output
Markaby::Builder.set(:indent, 2)
# We want a simple time-print
class Time
  def to_s
    day.to_s + "/" + month.to_s
  end
  
  def to_ss
    to_s + "/" + year.to_s
  end
end

DEBUG_LEVEL=5
def debug(level, s)
  if level <= DEBUG_LEVEL
    puts " " * level + s
  end
end

class NilClass
  def to_s_eu
    to_s
  end
end

class Date
  def month_s
    [ "janvier", "février", "mars", "avril", "mai", "juin",
      "juillet", "août", "septembre", "octobre", "novembre", "décembre" ][month-1]
  end
  
  def to_s_eu
    strftime('%d/%m/%y')
  end
  
  def Date.from_s(s)
    # Do some date-magic, so that we can give either the day, day and month or
    # a complete date. The rest is filled up with todays date.
    date = []
    if s.index("/")
      date = s.split("/")
    else
      date = s.split("-").reverse
    end
    da = Date.today
    d = [ da.day, da.month, da.year ]
    date += d.last( 3 - date.size )
    if date[2].to_s.size > 2
      date = Date.strptime( date.join("/"), "%d/%m/%Y" )
    else
      date = Date.strptime( date.join("/"), "%d/%m/%y" )
    end
    return date
  end
end

class Numeric
  # Returns a string with "pre" left digits and "post" right digits
  def fix( pre, post )
    m = 10**post
    # Round on "post" digits after the "."
    f = ( to_f * m ).round / m.to_f
    a, b = f.to_s.split( "." )
    b = "" if not b
    "#{a.rjust(pre)}.#{b.ljust(post,"0")}"
  end
end

class Array
  def sort_n
    self.sort{|a,b|
      a.to_i <=> b.to_i
    }
  end
end

SHOW_PERF=false
module Performance
  attr :perf_timer, :perf_timer_last
  def timer_start
    @perf_timer = @perf_timer_last = Time.now
  end
  # Reads the timer and prints out string, followed by
  # the time:
  # Total time, if +last+ is false
  # Time since last call if +last+ is true
  def timer_read( str, last = true )
    if SHOW_PERF
      $stdout.write "#{self.class.name}: #{str}"
      if last
        puts( ( Time.now - @perf_timer_last ).to_s )
      else
        puts( ( Time.now - @perf_timer ).to_s )
      end
    end
    @perf_timer_last = Time.now
  end
end
class PerformanceClass
  include Performance
end


# Own classes (perhaps I should've switched to RoR...
require 'account.rb'
require 'merge.rb'
require 'movement.rb'
require 'remote.rb'
require 'user.rb'
require 'report.rb'
require 'global.rb'
require 'admin.rb'

module Compta::Models
  # The compta has some +Account+s
  # Furthermore there are +Movement+s between +Account+s. 
  # All +Mouvement+s are balanced by design.
  
  class CreateCompta00 < V 0.1
    def self.up
      create_table :compta_accounts, :force => true do |t|
        t.column :account_id, :integer
        t.column :name,    :string, :limit => 255
        t.column :desc,     :text
        t.column :global_id, :string, :limit => 255
        t.column :revision, :integer
        t.column :total, :string, :limit => 255
      end
      create_table :compta_movements, :force => true do |t|
        t.column :account_src_id, :integer, :null => false
        t.column :account_dst_id, :integer, :null => false
        t.column :value, :real
        t.column :desc, :string, :limit => 255
        t.column :date, :date
        t.column :revision, :integer
        t.column :global_id, :string, :limit => 255
      end
      create_table :compta_remotes, :force => true do |t|
        t.column :url, :string, :limit => 255
        t.column :name, :string, :limit => 255
        t.column :pass, :string, :limit => 255
      end
      create_table :compta_users, :force => true do |t|
        t.column :name, :string, :limit => 255
        t.column :full, :string, :limit => 255
        t.column :pass, :string, :limit => 255
      end
      create_table :compta_accounts_users, :force => true, :id=>false do |t|
        t.column :account_id, :integer, :null => false
        t.column :user_id, :integer, :null => false
      end
      
      #      User.create_v01( "local", 
      #      Digest::MD5.hexdigest( ( rand 2**128 ).to_s ).to_s,
      #      rand( 2 ** 128 ).to_s )
    end
  end
  class CreateCompta01 < V 0.2
    def self.up
      add_column :compta_accounts, :multiplier, :float
      Account.find( :all ).each{ |acc|
        acc.multiplier = 1.0
        acc.save
      }
    end
  end
  
  # Adding of a counter on the client and the server side for more
  # fast merging:
  # Accounts and Movements get a changed "revision":
  # it is a global (one for Accounts and one for Movements)
  #  counter that increases steadily. If something is changed,
  #  the counter gets increased by one.
  #   Remote.account_index and Remote.movement_index point to the
  #  last Account and Movement transferred, while
  #   User.account_index and User.movement_index do the same on
  #  the server side
  #   User('local').account_index and User('local').movement_index
  #  point to the actual index used in the local database
  class CreateCompta02 < V 0.3
    def self.up
      # Add counter for Users, set initially to include all existing ones
      add_column :compta_users, :account_index, :integer
      add_column :compta_users, :movement_index, :integer
      # Add counter for Remotes, set initially to include all existing ones
      add_column :compta_remotes, :account_index, :integer
      add_column :compta_remotes, :movement_index, :integer
      
      # Add counter to accounts
      add_column :compta_accounts, :index, :integer
      remove_column :compta_accounts, :revision
      account_index = 1
      Account.find( :all ).each{ |acc|
        acc.index = account_index
        account_index += 1
        acc.save
      }
      
      # Add counter to movements
      add_column :compta_movements, :index, :integer
      # Why doesn't this exist anymore?
      # remove_column :compta_movements, :revision
      movement_index = 1
      Movement.find( :all ).each{ |mov|
        mov.index = movement_index
        movement_index += 1
        mov.save
      }
      
      # The local user is one higher than the others, because he holds
      # the next index
      # TODO: check why this doesn't work with a new database -> rm .camping*
      if not User.find_by_name('local')
        User.create( "local", 
          Digest::MD5.hexdigest( ( rand 2**128 ).to_s ).to_s,
          rand( 2 ** 128 ).to_s )
      end
      User.find( :all ).each{ |u|
        u.account_index = account_index
        u.movement_index = movement_index
        if u.name != 'local'
          u.account_index -= 1
          u.movement_index -= 1
        end
        debug 1, "#{u.name} has #{u.account_index}/#{u.movement_index}"
        u.save
      }
      u = User.find_by_name('local')
      debug 1, "after saving - #{u.name} has #{u.account_index}/#{u.movement_index}"
      
      # The remotes hold the last updated index.
      Remote.find( :all ).each{|r|
        r.account_index = account_index - 1
        r.movement_index = movement_index - 1
        r.save
      }
    end
  end

  # Adding a "deleted" field to accounts, so they get correctly
  # updatede once they're gone
  # Also add a "keep_total" field that makes the sum for that account be
  # reported from one year to another
  class CreateCompta03 < V 0.4
    def self.up
      # Add "deleted" field to accounts
      add_column :compta_accounts, :deleted, :boolean
      add_column :compta_accounts, :keep_total, :boolean
      
      Account.find( :all ).each{ |acc|
        acc.deleted = false
        # As most of the accounts in Cash have -1 and shall be kept, this
        # gives a good first initialisation
        acc.keep_total = acc.multiplier == -1
        debug 3, "Account #{acc.path} has keep_total of #{acc.keep_total.inspect}"
        acc.save
      }
    end
  end
end


module Compta::Controllers
  class Index < R '/'
    def get
      render :index
    end
  end
end


module Compta::Views
  @debug = false
  
  def list_sub( accs, indent = "" )
    accs.sort!{ |a,b| 
      a.name <=> b.name
    }
    accs.each{ |a|
      if not a.deleted
        yield a, indent + a.name # + ", id: " + a.id.to_s + ", parent-account: " + a.account_id.to_s
        list_sub( a.accounts, indent + "+" ){ |a, s| yield a, s }
      end
    }
  end
    
  def layout
    if @nolayout then
      return yield
    else
      html do
        head do
          style :type => "text/css", :media => "screen" do
            %[
body {
 background-color:#55ff55;
}

div.main {
 border:1px solid red;
 padding:5px;
 background-color:#ddffdd;
 text-align:left;
 margin-left:2%;
 margin-right:2%;
 margin-top:2%;
}

a {
 color:#009900;
 text-decoration:none;
}

td.small { 
  font-size: 9px; 
  valign: center 
}

td.money {
  text-align: right;
  font-family: monospace
}
            ]
          end
          style :type => "text/css", :media => "print" do
            %[
            td.small { 
              font-size: 9px; 
              valign: center 
            }
            
            td.money {
              text-align: right;
              font-family: monospace
            } 

            a {
             color:#000000;
             text-decoration:none;
            }
            ]           
          end
        end
        body do
          div :class => "main" do
            self << yield
          end
        end
      end
    end
  end
end

def index
  h1 "AfriCompta - page principale"
  h2 "Listes"
  ul {
    li { a "Movements", :href => "/movement/list" }
    li { a "Comptes", :href => "/account/list" }
    #li { a "Salaires", :href => "/salary/list" }
    li { a "Grand livre", :href => "/global/list"}
    li { a "Utilisateurs", :href => "/user/list" }
    #li { a "Employées", :href => "/employee/list" }
    li { a "Destinations", :href => "/remote/list" }
  }
  h2 "Rapports"
  ul {
    li {
      table :border=>"0" do
        [ [ "annuel", "year" ], [ "mensuel", "month"] , [ "hébdomadaire", "cweek" ] ].each{|per|
          tr {
            td per[0]
            td { a "séparé", :href => "/report/?type=cumul&period=#{per[1]}" }
            td { a "absolu", :href => "/report/?type=abs&period=#{per[1]}" }
            td { a "arbre", :href => "/report/?type=cumul&period=#{per[1]}&depth=1" }
          }
        }
      end
    }
  }
  #h2 "Ajouter"
  #ul {
  #  li { a "un compte", :href => "/account/add" }
  #  li { a "un utilisateur", :href => "/user/add" }
  #  li { a "une destination", :href => "/remote/add" }
  #  li { a "un employée", :href => "/employee/add" }
  #}
  h2 "Suppléments"
  ul {
    li { a "ranger un peu", :href => "/admin/clean"}
  }
end

def Compta.create
  Compta::Models.create_schema
end

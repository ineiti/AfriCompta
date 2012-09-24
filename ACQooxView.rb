# AfriCompta - handler of a simple accounting-system for "Gestion"
#
# What follows are some definitions used by other modules

# We want a simple time-print
class Time
  def to_s
    day.to_s + "/" + month.to_s
  end
  
  def to_ss
    to_s + "/" + year.to_s
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


class SQLiteAC < SQLite
	def configure( config )
		filename = get_config( "compta.db", :AfriCompta, :filename )
		super( config, "compta", filename )
	end
end

require 'ACaccess'
Dir[File.dirname(__FILE__) + "/Entities/*.rb"].each{|f| 
	require(f)
	dputs 2, "Adding #{f}"
}

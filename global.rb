module Compta::Models
  
end


module Compta::Controllers
  class GlobalClasses < R '/global/(.*)'
    def get(p)
      arg1, @year, @start = p.split("/")
      @movements = Movement.find :all
      case arg1
        when "date"
        puts "Sorting movements"
        @movements.sort! {|a,b|
          if a.date == b.date
            if a.desc == b.desc
              a.global_id <=> b.global_id
            else
              a.desc <=> b.desc
            end
          else
            a.date <=> b.date
          end
        }
      end
      render :list
    end
  end
end


module Compta::Views
  def list
    h1 "Le grand livre"
    table :border => "1" do
      tr {
        td "Date"
        td "Description"
        td "Montant"
        td "Source"
        td "Destination"
        td "Id globale"
      }
      @movements.each{|m|
        tr {
          [ m.date.to_s, m.desc, m.value, m.account_src.name, m.account_dst.name, m.global_id ].each{|str|
            td str
          } 
        }
      }
    end
  end
end
module Compta::Models
  
end


module Compta::Controllers
  class GlobalClasses < R '/global/(.*)'
    def get(p)
      @sort, @year = p.split("/")
      @movements = []
      @year_list = ["Actual"]
      if archives = Account.get_archive
        @year_list += archives.accounts_nondeleted.collect{|a|
          a.name
        }.sort.reverse
      end
      
      if not @year or @year == "Actual"
        @year = "Actual"
        Account.get_root.get_tree{|a|
          @movements += a.movements
        }
      else
        Account.get_archive.accounts_nondeleted.select{|a|
          a.name == @year
        }.first.get_tree{|a|
          @movements += a.movements
        }
      end
      @movements.uniq!
      
      case @sort
      when "gid"
        @movements.sort! {|a,b|
          a.global_id.gsub(/.*-/, '') <=> b.global_id.gsub(/.*-/, '')
        }
      else
        @sort = "date"
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
      @movements.reverse!
      render :list
    end
  end
end


module Compta::Views
  def list
    h1 "Le grand livre"
    table :border => "1" do
      sort_other = @sort == 'date' ? 'gid' : 'date'
      a "Sort: #{sort_other}", :href => "/global/#{sort_other}/#{@year}"
      b " -:- "
      @year_list.each{|y|
        a y, :href => "/global/#{@sort}/#{y}"
        b "-"
      }
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
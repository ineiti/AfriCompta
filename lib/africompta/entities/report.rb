class ReportAccounts < Entities
  def setup_data
    value_entity_account :root, :drop, :path
    value_entity_account :account, :drop, :path
    value_int :level
  end
end


class Reports < Entities
  def setup_data
    value_str :name
    value_list_entity_reportAccounts :accounts
  end
end

class Report < Entity
  attr_accessor :print_accounts, :print_movements, :print_account

  def print_account_monthly(acc, start, months, counter)
    stop = (start >> months) - 1

    line = []
    zeros = false
    @print_account = ''
    @print_accounts = counter.to_f / accounts.count
    p_a = 0
    acc.account.get_tree(acc.level.to_i) { |acc_sub, depth|
      acc_sub.get_tree(depth > 0 ? 0 : -1) { p_a += accounts.count }
    }
    acc.account.get_tree(acc.level.to_i) { |acc_sub, depth|
      dputs(2) { "Doing #{acc_sub.path} - #{depth.inspect}. Done: #{@print_accounts}" }
      sum = Array.new(months) { 0 }
      acc_sub.get_tree(depth > 0 ? 0 : -1) { |acc_sum|
        @print_account = acc_sum.get_path
        @print_accounts += 1.0 / p_a
        p_m = 1.0 / acc_sum.movements.count
        @print_movements = 0
        acc_sum.movements.each { |m|
          @print_movements += p_m
          if (start..stop).include? m.date
            sum[m.date.month - start.month] += m.get_value(acc_sum)
          end
        }
      }
      if sum.inject(false) { |m, o| m |= o != 0 } or line.size == 0
        if line.size == 0
          zeros = true
        elsif zeros
          line = []
          zeros = false
        end
        line.push [acc_sub.path, sum + [sum.inject(:+)]]
      end
    }
    line
  end

  def print_heading_monthly(start = Date.today, months = 12)
    ['Period', (0...months).collect { |m|
               (start >> m).strftime('%Y/%m')
             } + ['Sum']]
  end

  def print_list_monthly(start = Date.today, months = 12)
    stop = start >> (months - 1)
    acc_counter = -1
    list = accounts.collect { |acc|
      line = print_account_monthly(acc, start, months, acc_counter += 1)
      if line.size > 1
        line.push ['Sum', line.reduce(Array.new(months+1, 0)) { |memo, obj|
                          dputs(2) { "#{memo}, #{obj.inspect}" }
                          memo = memo.zip(obj[1]).map { |a, b| a + b }
                        }]
      end
      line
    }
    if list.size > 1
      list + [[['Total', running = list.reduce(Array.new(months+1, 0)) { |memo, obj|
                         dputs(2) { "#{memo}, #{obj.inspect}" }
                         memo = memo.zip(obj.last.last).map { |a, b| a + b }
                       }],
               ['Running', running[0..-2].reduce([]) { |m, o| m + [(m.last || 0) + o] }]]]
    else
      list
    end
  end

  def print(start = Date.today, months = 12)

  end

  def listp_accounts
    accounts.collect { |a|
      [a.id, "#{a.level}: #{a.account.path}"]
    }
  end

  def print_pdf_monthly(start = Date.today, months = 12)
    stop = start >> (months - 1)
    file = "/tmp/report_#{name}.pdf"
    Prawn::Document.generate(file,
                             :page_size => 'A4',
                             :page_layout => :landscape,
                             :bottom_margin => 2.cm) do |pdf|

      pdf.text "Report for #{name}",
               :align => :center, :size => 20
      pdf.font_size 7
      pdf.text "From #{start.strftime('%Y/%m')} to #{stop.strftime('%Y/%m')}"
      pdf.move_down 1.cm

      pdf.table([print_heading_monthly(start, months).flatten.collect { |ch|
                   {:content => ch, :align => :center} }] +
                    print_list_monthly(start, months).collect { |acc|
                      acc.collect { |a, values|
                        [a] + values.collect { |v| Account.total_form(v) }
                      }
                    }.flatten(1).collect { |line|
                      a, s = (line[0] =~ /::/ ? [:left, :normal] : [:right, :bold])
                      [{:content => line.shift, :align => a, :font_style => s}] +
                          line.collect { |v|
                            {:content => v, :align => :right, :font_style => s} }
                    },
                :header => true)
      pdf.move_down(2.cm)

      pdf.repeat(:all, :dynamic => true) do
        pdf.draw_text "#{Date.today} - #{name}",
                      :at => [0, -20], :size => 10
        pdf.draw_text pdf.page_number, :at => [18.cm, -20]
      end
    end
    file
  end
end
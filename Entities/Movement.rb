class Movements < Entities
  def setup_data
    dputs( 0 ){ "init_movements" }
    @default_type = :SQLiteAC
    @data_field_id = :id

    value_entity_account :account_src_id
    value_entity_account :account_dst_id
    value_float :value
    value_str :desc
    value_date :date
    value_int :revision
    value_str :global_id
    value_int :index
  end

  def self.from_json( str )
    self.from_s( ActiveSupport::JSON.decode( str )["str"] )
  end
    
  def self.from_s( str )
    str.force_encoding( Encoding::UTF_8 )
    desc, str = str.split("\r")
    global_id, value, date, src, dst = str.split("\t")
    #date = Time.parse(date).to_ss
    date = Date.strptime(date, "%Y-%m-%d" )
    value = value.to_f
    a_src = Accounts.match_by_global_id( src )
    a_dst = Accounts.match_by_global_id( dst )
    if not a_src or not a_dst
      dputs( 0 ){ "error: didn't find " + src.to_s + " or " + dst.to_s }
      return [ -1, nil ]
    end
    # Does the movement already exist?
    our_m = nil
    if not ( our_m = self.match_by_global_id(global_id) )
      dputs( 3 ){ "New movement" }
      our_m = self.create( desc, date, value, 
        a_src, a_dst )
      our_m.global_id = global_id
    else
      dputs( 2 ){ "Overwriting movement at #{our_m.index}:#{our_m.id} -> #{global_id}" }
      # And update it
      our_m.set( desc, date, value, a_src.id, a_dst.id )
      dputs( 2 ){ "Now we're #{our_m.index}:#{our_m.id} -> #{global_id}" }
    end
    return our_m
  end

  def create( desc, date, value, source, dest )
    return nil if source == dest
    t = super( :desc => desc, :date => date, :value => 0, 
      :account_src_id => source.id, :account_dst_id => dest.id )
    t.value = value
    t.global_id = Users.match_by_name("local").full + "-" + t.id.to_s
    t.new_index
    dputs( 4 ){ t.to_json }
    t
  end
end



class Movement < Entity
  def new_index()
    u_l = Users.match_by_name('local')
    self.index = u_l.movement_index.to_i
    u_l.movement_index = self.index + 1
    dputs( 3 ){ "index is #{self.index} and date is --#{self.date}--" }
    dputs( 3 ){ "User('local').index is: " + Users.match_by_name('local').movement_index.to_s }
  end
    
  def get_index()
    return self.index
  end
    
  def is_in_account(a)
    return ( a == account_src or a == account_dst )
  end
    
  def value=(v)
    if account_src and account_dst
      dputs( 3 ){ "value=" + v.to_s + ":" + account_src.total.to_s }
      diff = value.to_f - v
      account_src.total = account_src.total.to_f + ( diff * account_src.multiplier )
      account_dst.total = account_dst.total.to_f - ( diff * account_dst.multiplier )
    end
    data_set_log( :_value, v, @proxy.msg, @proxy.undo, @proxy.logging )
  end
    
  def get_value( account )
    account_side = ( account_src == account ? -1 : 1 )
    dputs( 5 ){ "account_src #{account_src.inspect} == account #{account.inspect}" }
    dputs( 5 ){ "Account_side = #{account_side}" }
    value.to_f * account.multiplier.to_f * account_side
  end
    
  def get_other_account( account )
    account_src == account ? account_dst : account_src
  end
    
  def set( desc, date, value, source, dest )
    dputs( 3 ){ "self.value " + self.value.to_s + " - " + value.to_s }
    self.value = 0
    self.account_src_id, self.account_dst_id = source, dest
    if false
      # Do some date-magic, so that we can give either the day, day and month or
      # a complete date. The rest is filled up with todays date.
      date = date.split("/")
      da = Date.today
      d = [ da.day, da.month, da.year ]
      date += d.last( 3 - date.size )
      if date[2].to_s.size > 2
        self.date = Date.strptime( date.join("/"), "%d/%m/%Y" )
      else
        self.date = Date.strptime( date.join("/"), "%d/%m/%y" )
      end
    else
      self.date = Date.from_s(date.to_s)
    end
    self.desc, self.value = desc, value
    dputs( 4 ){ "Getting new index" }
    self.new_index()
    dputs( 4 ){ "Date " + self.date.to_s }
  end
    
  def to_s
    dputs( 5 ){ "I am: #{to_hash.inspect} - my id is: #{global_id}" }
    "#{desc}\r#{global_id}\t" + 
      "#{value.to_s}\t#{date.to_s}\t" +
      account_src.global_id.to_s + "\t" +
      account_dst.global_id.to_s
  end
	
  def to_json
    ActiveSupport::JSON.encode( :str => to_s )
  end

  # Copying over data from old AfriCompta
  def account_src
    account_src_id
  end
	
  def account_dst
    account_dst_id
  end
  
  def delete
    dputs(4){"Deleting movement #{desc}"}
    src, dst = account_src, account_dst
    dputs(3){"totals before: #{src.get_path}=#{src.total}, " + 
        "#{dst.get_path}=#{dst.total}"}
    self.value = 0
    dputs(3){"totals after: #{src.get_path}=#{src.total}, " + 
        "#{dst.get_path}=#{dst.total}"}
    super
  end
end

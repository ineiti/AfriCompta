class Schema_Infos < Entities
  def setup_data
    @default_type = :SQLiteAC
    @data_field_id = :id
    
    value_str :version
  end

  def migration_1(s)
    s.version = '0.4'
  end

  def migration_2(s)
    s.version = '0.5'
  end
end

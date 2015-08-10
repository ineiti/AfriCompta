class ConfigBases < Entities
  def add_config
    value_block :vars_narrow

    value_block :vars_wide

    @@functions = %i( accounting accounting_standalone )
  end
end
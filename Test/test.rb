#!/usr/bin/ruby -I../../QooxView -I.. -wKU
require 'test/unit'

CONFIG_FILE="config_test.yaml"
DEBUG_LVL=2

require 'QooxView'
require 'ACQooxView'

Permission.add( 'default', 'View,Welcome' )
Permission.add( 'admin', '.*', '.*' )
Permission.add( 'internet', 'Internet,PersonShow', 'default' )
Permission.add( 'student', '', 'internet' )
Permission.add( 'professor', '', 'student' )
Permission.add( 'secretary', 'PersonModify', 'professor' )

qooxView = QooxView.init( '../Entities', '../Views' )

tests = %w( africompta account )
#tests = %w( africompta )
#tests = %w( account )
tests.each{|t|
  require "ac_#{t}"
}

# Fails test_archive_sum_up

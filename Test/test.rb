#!/usr/bin/env ruby
##!/usr/local/bin/ruby -I.
##!/usr/bin/ruby -I.. -I../../QooxView -I../../AfriCompta -I../../LibNet -I. -wKU
%w( QooxView AfriCompta LibNet ).each{|l|
  $LOAD_PATH.push "../../#{l}"
}
$LOAD_PATH.push "."

require 'test/unit'

CONFIG_FILE="config_test.yaml"
DEBUG_LVL=0

require 'QooxView'
require 'ACQooxView'
require 'ACaccess'

Permission.add( 'default', 'View,Welcome' )
Permission.add( 'admin', '.*', '.*' )
Permission.add( 'internet', 'Internet,PersonShow', 'default' )
Permission.add( 'student', '', 'internet' )
Permission.add( 'professor', '', 'student' )
Permission.add( 'secretary', 'PersonModify', 'professor' )

qooxView = QooxView.init( '../Entities', '../Views' )

tests = %w( africompta account movement )
#tests = %w( africompta )
#tests = %w( movement )
tests.each{|t|
  require "ac_#{t}"
}

# Fails test_archive_sum_up

#!/usr/bin/env ruby
##!/usr/local/bin/ruby -I.
##!/usr/bin/ruby -I.. -I../../QooxView -I../../AfriCompta -I../../LibNet -I. -wKU
%w( QooxView AfriCompta HelperClasses/lib ).each{|l|
  $LOAD_PATH.push "../../#{l}"
}
$LOAD_PATH.push '.'

require 'test/unit'
require 'fileutils'

FileUtils.rm_rf('data/')
FileUtils.rm_rf('data2/')

$config_file='config_test.yaml'
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

tests = %w( africompta account movement sqlite )
#tests = %w( africompta )
#tests = %w( sqlite )
#tests = %w( big )
tests.each{|t|
  require "ac_#{t}"
}

# Fails test_archive_sum_up

#!/usr/bin/env ruby

require 'bundler/setup'
require 'test/unit'
require 'fileutils'

FileUtils.rm_rf('data2/')

$config_file='config_test.yaml'
DEBUG_LVL=1

require 'QooxView'
require 'africompta'

Permission.add('default', 'View,Welcome')
Permission.add('admin', '.*', '.*')
Permission.add('internet', 'Internet,PersonShow', 'default')
Permission.add('student', '', 'internet')
Permission.add('professor', '', 'student')
Permission.add('secretary', 'PersonModify', 'professor')

qooxView = QooxView.init('../Entities', '../Views')

tests = Dir.glob('ac_*.rb')
# tests = %w( africompta account movement sqlite )
#tests = %w( africompta )
tests = %w( account )
#tests = %w( merge )
dp tests
tests.each { |t|
  begin
    require_relative "ac_#{t}"
  rescue LoadError => e
    require_relative t
  end
}

# Fails test_archive_sum_up

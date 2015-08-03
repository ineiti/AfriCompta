require 'bundler/setup'
require 'qooxview'
require 'africompta/acaccess'
require 'africompta/acqooxview'

AFRICOMPTA_DIR = File.join(File.dirname(__FILE__), 'africompta')
QooxView.load_dirs(%w(entities views).collect { |d|
                     File.join(AFRICOMPTA_DIR, d) })

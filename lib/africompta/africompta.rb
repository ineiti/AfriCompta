#!/usr/bin/ruby -I../QooxView -wKU

DEBUG_LVL=5
VERSION_AFRICOMPTA='1.9.8'
require 'fileutils'

AFRICOMPTA_DIR=File.dirname(__FILE__)
CONFIG_FILE='config.yaml'
if not FileTest.exists? CONFIG_FILE
  puts "Config-file doesn't exist"
  print 'Do you want me to copy a standard one? [Y/n] '
  if gets.chomp.downcase != 'n'
    FileUtils.cp 'config.yaml.default', 'config.yaml'
  end
end

begin
  require 'qooxview'
  require 'africompta/acqooxview'
rescue Exception => e
  puts e.inspect
  puts e.to_s
  puts e.backtrace

  dputs( 0 ){ "#{e.inspect}" }
  dputs( 0 ){ "#{e.to_s}" }
  puts e.backtrace

  puts "Couldn't start AfriCompta - perhaps missing libraries?"
  exit
end

Welcome.nologin
QooxView::init( 'entities', 'views')

# Autosave every 2 minutes
if ConfigBase.autosave == %w(true)
  $autosave = Thread.new{
    loop {
      sleep 2 * 60
      Entities.save_all
    }
  }
end

trap('SIGINT') {
  throw :ctrl_c
}

$profiling = get_config( nil, :profiling )
catch :ctrl_c do
  begin
    webrick_port = get_config( 3302, :Webrick, :port )
    dputs(2){"Starting at port #{webrick_port}" }
    if $profiling
      require 'rubygems'
      require 'perftools'
      PerfTools::CpuProfiler.start("/tmp/#{$profiling}") do
        QooxView::startWeb webrick_port
      end
    else
      QooxView::startWeb webrick_port
    end
  rescue Exception => e
  dputs( 0 ){ "#{e.inspect}" }
  dputs( 0 ){ "#{e.to_s}" }
  puts e.backtrace
    dputs( 0 ){ 'Saving all' }
    Entities.save_all
  end
end

if get_config( true, :autosave )
  $autosave.kill
end

if $profiling
  puts "Now run the following:
pprof.rb --pdf /tmp/#{$profiling} > /tmp/#{$profiling}.pdf
open /tmp/#{$profiling}.pdf
CPUPROFILE_FREQUENCY=500
    "
end

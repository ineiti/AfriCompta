#!/usr/bin/env ruby
# encoding: UTF-8

if ARGV == %w(-p)
  DEBUG_LVL = 0
else
  DEBUG_LVL = 2
end

require 'bundler/setup'
require 'helper_classes'
include HelperClasses
include System

Encoding.default_external = Encoding::UTF_8

require 'fileutils'

CONFIG_FILE=File.join('..', 'config.yaml')
if not FileTest.exists? CONFIG_FILE
  puts "Config-file doesn't exist, copying a standard one"
  FileUtils.cp "#{CONFIG_FILE}.default", CONFIG_FILE
end

begin
  require 'qooxview'
  require 'africompta'
rescue Exception => e
  puts "#{e.inspect}"
  puts "#{e.to_s}"
  puts e.backtrace
  exit
end

begin
  QooxView::init('entities', 'views')
rescue Exception => e
  case e.to_s
    when /UpdatePot|MakeMo|PrintHelp|value_entity_uncomplete/
    else
      puts e.inspect
      puts e.backtrace
      dputs(0) { "Error: Couldn't load things!" }
      dputs(0) { "#{e.inspect}" }
      dputs(0) { "#{e.to_s}" }
      puts e.backtrace
  end
  exit
end

webrick_port = get_config(3302, :Webrick, :port)
dputs(2) { "Starting at port #{webrick_port}" }

$profiling = get_config(nil, :profiling)
if $profiling
  dputs(1) { 'Starting Profiling' }
  require 'rubygems'
  require 'perftools'
  PerfTools::CpuProfiler.start("/tmp/#{$profiling}") do
    QooxView::startWeb webrick_port, get_config(30, :profiling, :duration)
    dputs(1) { 'Finished profiling' }
  end

  if $profiling
    puts "Now run the following:
pprof.rb --pdf /tmp/#{$profiling} > /tmp/#{$profiling}.pdf
open /tmp/#{$profiling}.pdf
CPUPROFILE_FREQUENCY=500
    "
  end
else
  dputs(1) { 'Starting autosave' }
  $autosave = Thread.new {
    loop {
      sleep 60
      rescue_all "Error: couldn't save all" do
        Entities.save_all
      end
    }
  }

  # Shows time every minute in the logs
  if get_config(false, :showTime)
    dputs(1) { 'Showing time' }
    $show_time = Thread.new {
      loop {
        sleep 60
        dputs(1) { 'It is now: ' + Time.now.strftime('%Y-%m-%d %H:%M') }
      }
    }
  end

  # Catch SIGINT signal so we can save everything before quitting
  trap('SIGINT') {
    throw :ctrl_c
  }

  # Finally start QooxView
  catch :ctrl_c do
    rescue_all 'Error: QooxView aborted' do
      log_msg :main, "Started Gestion on port #{webrick_port}"
      images_path = File.join(File.expand_path(File.dirname(__FILE__)), 'Images')
      RPCQooxdooHandler.add_file_path(:Images, images_path)
      include HelperClasses::HashAccessor
      $config = {}
      Welcome.nologin
      QooxView::startWeb webrick_port
    end
  end

  # Clean up all threads
  if get_config(true, :autosave)
    $autosave.kill
  end
  $show_time and $show_time.kill

  # And finally save all before quitting
  Entities.save_all
end

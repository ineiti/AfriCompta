#!/usr/bin/env ruby
# encoding: UTF-8
Encoding.default_external = Encoding::UTF_8

require 'bundler/setup'
require 'africompta'

QooxView::init('entities', 'views')

webrick_port = 3303
dputs(2) { "Starting at port #{webrick_port}" }

# Set default functions to use africompta
ConfigBase.set_functions(%w(accounting accounting_standalone))
Welcome.nologin
Users.create(name:'other', pass:'other')
Users.create(name:'other2', pass:'other2')
QooxView::startWeb(webrick_port)

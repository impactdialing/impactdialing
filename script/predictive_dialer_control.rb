#!/usr/bin/env ruby
require 'rubygems'
require 'daemons'

RAILS_ROOT = File.expand_path('../..', __FILE__)

Daemons.run(File.join(RAILS_ROOT, 'lib', 'predictive_dialer.rb'), {:ARGV => ARGV})

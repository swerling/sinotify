require File.join(File.dirname(__FILE__), 'sinotify_info')

require 'rubygems'
require 'cosell'
require 'logger'
require File.join(File.dirname(__FILE__), '../ext/sinotify.so')
Sinotify.require_all_libs_relative_to(__FILE__)


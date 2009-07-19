ext_lib = File.join(File.dirname(__FILE__), '../ext/sinotify.so')
unless File.exist?(ext_lib)
  raise "Could not find ext/sinotify.so. \n" \
      + "Please build the sinotify.so extention first (cd [sinotify gem]/ext && ruby extconf.rb && make)" 
end

# load base info and c lib
require ext_lib
require File.join(File.dirname(__FILE__), 'sinotify_info')

# load external dependencies
require 'rubygems'
require 'cosell'
require 'logger'

# load application
Sinotify.require_all_libs_relative_to(__FILE__)


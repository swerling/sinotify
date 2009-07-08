require 'mkmf'

dir = File.join(File.dirname(__FILE__))

if RUBY_VERSION =~ /1.9/ then  
  $CPPFLAGS += " -DRUBY_19"  
end  

have_header('linux/inotify.h')
# this was in the original inotify, but I don't know what it is for:
# have_header("version.h")
create_makefile('sinotify', 'src')

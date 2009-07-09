sinotify
    by Steven Swerling
    http://tab-a.slot-z.net

== DESCRIPTION:

Primary difference with regular inotify wrapper libs is that the events are queued and emitted from a background
thread. Also simplified the event model.
TODO

What is inotify: 

  on linux, type 'man inotify'
  on others, 'google inotify' 

The 's' in 'sinotify' in fact stands for 'suck:' 
  http://www.kernel.org/pub/linux/kernel/people/rml/inotify/README

xxVersion of ruby-inotify tweaked to:

Inotify is a linux library for sending event notification when something on the file system
has changed. (see 'man inotify' for detail). This is a wrapper for the linux inotify library
for ruby. This package derived from aredridel's package (http://raa.ruby-lang.org/project/ruby-inotify/).

Differences from aredridel's package:

 1. Use standard event pattern for notfication (rather than synchronous loop)
 2. Ability to create a recursive watch (in otherwords, specify a directory
    and receive notification on any changes w/in that directory or its children)
 3. The suggestion made by Paul Boon for making the event_check thread more well
    behaved (see http://www.mindbucket.com/2009/02/24/ruby-daemons-verifying-good-behavior/)

The name 'sinotify' is a concatenation of 'sinai' and 'inotify'. This project was factored of and designed to 
support 'sinai'. 

== FEATURES/PROBLEMS:

* None known.

== SYNOPSIS:

Setup:

  $ mkdir /tmp/sinotify_test
  $ irb
  require 'sinotify'
  notifier = Sinotify::Notifier.new('/tmp/sinotify_test', :recurse => true, :etypes => [:create, :modify, :delete])
  notifier.spy!(:logger => Logger.new('/tmp/inotify_events.log')) # optional event spy
  notifier.when_announcing(Sinotify::Event) do |sinotify_event|
    puts "Event happened at #{sinotify_event.timestamp} on #{sinotify_event.path}, etypes => #{sinotify_event.etypes.inspect}"
  end
  notifier.watch! # don't forget to start the watch

Then in another linux console: 

  $ touch /tmp/sinotify_test/hi && sleep 1 && echo 'hello' >> /tmp/sinotify_test/hi && sleep 1 && rm -r /tmp/sinotify_test
  
Back in irb you will see:

  Event happened at Wed Jul 08 22:47:46 -0400 2009 on /tmp/sinotify_test/hi, etypes => [:create]
  Event happened at Wed Jul 08 22:47:47 -0400 2009 on /tmp/sinotify_test/hi, etypes => [:modify]
  Event happened at Wed Jul 08 22:47:48 -0400 2009 on /tmp/sinotify_test/hi, etypes => [:delete]
  Event happened at Wed Jul 08 22:47:48 -0400 2009 on /tmp/sinotify_test, etypes => [:delete]

tail -n 50 -f /tmp/inotify_events.log:

  ... INFO -- : Sinotify::Notifier Prim Event Spy: <Sinotify::PrimEvent :name => 'hi', :etypes => [:create], :mask => 100 ...
  ... INFO -- : Sinotify::Notifier Event Spy <Sinotify::Event :path => '/tmp/sinotify_test/hi', dir? => false, :etypes =>  ...
  ... INFO -- : Sinotify::Notifier Prim Event Spy: <Sinotify::PrimEvent :name => 'hi', :etypes => [:modify], :mask => 2 ...
  ... INFO -- : Sinotify::Notifier Event Spy <Sinotify::Event :path => '/tmp/sinotify_test/hi', dir? => false, :etypes => ...
  ... INFO -- : Sinotify::Notifier Prim Event Spy: <Sinotify::PrimEvent :name => 'hi', :etypes => [:delete], :mask => 200 ...
  ... INFO -- : Sinotify::Notifier Event Spy <Sinotify::Event :path => '/tmp/sinotify_test/hi', dir? => false, :etypes => ...
  ... INFO -- : Sinotify::Notifier Prim Event Spy: <Sinotify::PrimEvent :name => '', :etypes => [:delete_self], :mask => 400 ...
  ... INFO -- : Sinotify::Notifier Event Spy <Sinotify::Event :path => '/tmp/sinotify_test', dir? => true, :etypes => [:delete]...

    

== REQUIREMENTS:

* linux inotify dev libs
* cosell announcements framework gem

== INSTALL:

* sudo gem install cosell...
* sudo gem install sinotify...

== LICENSE:

(The MIT License)

Copyright (c) 2008 FIXME (different license?)

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

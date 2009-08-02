sinotify 

by {Steven Swerling}[http://tab-a.slot-z.net]

{rdoc}[http://tab-a.slot-z.net] | {github}[http://www.github.com/swerling/sinotify]

== DESCRIPTION:

ALPHA Alert -- just uploaded initial release. 


Linux inotify is a means to receive events describing file system activity (create, modify, delete, close, etc). 

Sinotify was derived from aredridel's package (http://raa.ruby-lang.org/project/ruby-inotify/), with the addition of
Paul Boon's tweak for making the event_check thread more polite (see
http://www.mindbucket.com/2009/02/24/ruby-daemons-verifying-good-behavior/)

In sinotify, the classes Sinotify::PrimNotifier and Sinotify::PrimEvent provide a low level wrapper to inotify, with
the ability to establish 'watches' and then listen for inotify events using one of inotify's synchronous event loops,
and providing access to the events' masks (see 'man inotify' for details). Sinotify::PrimEvent class adds a little semantic sugar
to the event in to the form of 'etypes', which are just ruby symbols that describe the event mask. If the event has a
raw mask of (DELETE_SELF & IS_DIR), then the etypes array would be [:delete_self, :is_dir]. 

In addition to the 'straight' wrapper in inotify, sinotify provides an asynchronous implementation of the 'observer
pattern' for notification. In other words, Sinotify::Notifier listens in the background for inotify events, adapting
them into instances of Sinotify::Event as they come in and immediately placing them in a concurrent queue, from which
they are 'announced' to 'subscribers' of the event.  [Sinotify uses the 'cosell' implementation of the Announcements
event notification framework, hence the terminology 'subscribe' and 'announce' rather then 'listen' and 'trigger' used
in the standard event observer pattern. See the 'cosell' package on github for details.]

A variety of 'knobs' are provided for controlling the behavior of the notifier: whether a watch should apply to a
single directory or should recurse into subdirectores, how fast it should broadcast queued events, etc (see
Sinotify::Notifier, and the example in the synopsis section below). An event 'spy' can also be setup to log all
Sinotify::PrimEvents and Sinotify::Events.

Sinotify::Event simplifies inotify's muddled event model, sending events only for those files/directories that have
changed. That's not to say you can't setup a notifier that recurses into subdirectories, just that any individual
event will apply to a single file, and not to its children. Also, event types are identified using words (in the form
of ruby :symbols) instead of inotify's event masks. See Sinotify::Event for more explanation. 

The README for inotify:

  http://www.kernel.org/pub/linux/kernel/people/rml/inotify/README

Selected quotes from the README for inotify:

  * "Rumor is that the 'd' in 'dnotify' does not stand for 'directory' but for 'suck.'"

  * "The 'i' in inotify does not stand for 'suck' but for 'inode' -- the logical
    choice since inotify is inode-based."
  
(The 's' in 'sinotify' does in fact stand for 'suck.')


== FEATURES/PROBLEMS:

* None known. But it's still early.

== SYNOPSIS:

Try this:

  $ mkdir /tmp/sinotify_test
  $ irb
  require 'sinotify'
  notifier = Sinotify::Notifier.new('/tmp/sinotify_test', :recurse => true, :etypes => [:create, :modify, :delete])
  notifier.spy!(:logger => Logger.new('/tmp/inotify_spy.log')) # optional event spy
  notifier.on_event do |sinotify_event|
    puts "Event happened at #{sinotify_event.timestamp} on #{sinotify_event.path}, etypes => #{sinotify_event.etypes.inspect}"
  end
  notifier.on_event do |sinotify_event|
    puts "    --> demonstrate that multiple subscribers can be setup: #{sinotify_event.etypes.inspect}"
  end
  notifier.watch! # don't forget to start the watch

Then in another linux console: 

  $ touch /tmp/sinotify_test/hi && sleep 1 && echo 'hello' >> /tmp/sinotify_test/hi && sleep 1 && rm -r /tmp/sinotify_test
  
Back in irb you will see:

  Event happened at Sat Jul 11 12:29:18 -0400 2009 on /tmp/sinotify_test/hi, etypes => [:create]
      --> demonstrate that multiple subscribers can be setup: [:create]
  Event happened at Sat Jul 11 12:29:19 -0400 2009 on /tmp/sinotify_test/hi, etypes => [:modify]
      --> demonstrate that multiple subscribers can be setup: [:modify]
  Event happened at Sat Jul 11 12:29:20 -0400 2009 on /tmp/sinotify_test/hi, etypes => [:delete]
      --> demonstrate that multiple subscribers can be setup: [:delete]
  Event happened at Sat Jul 11 12:29:20 -0400 2009 on /tmp/sinotify_test, etypes => [:delete]
      --> demonstrate that multiple subscribers can be setup: [:delete]


tail -n 50 -f /tmp/inotify_spy.log:

  ...
  ... INFO -- : Sinotify::Notifier Prim Event Spy: <Sinotify::PrimEvent :name => 'hi', :etypes => [:create], :mask => 100 ...
  ... INFO -- : Sinotify::Notifier Event Spy <Sinotify::Event :path => '/tmp/sinotify_test/hi', dir? => false, :etypes =>  ...
  ... INFO -- : Sinotify::Notifier Prim Event Spy: <Sinotify::PrimEvent :name => 'hi', :etypes => [:modify], :mask => 2 ...
  ... INFO -- : Sinotify::Notifier Event Spy <Sinotify::Event :path => '/tmp/sinotify_test/hi', dir? => false, :etypes => ...
  ... INFO -- : Sinotify::Notifier Prim Event Spy: <Sinotify::PrimEvent :name => 'hi', :etypes => [:delete], :mask => 200 ...
  ... INFO -- : Sinotify::Notifier Event Spy <Sinotify::Event :path => '/tmp/sinotify_test/hi', dir? => false, :etypes => ...
  ... INFO -- : Sinotify::Notifier Prim Event Spy: <Sinotify::PrimEvent :name => '', :etypes => [:delete_self], :mask => 400 ...
  ... INFO -- : Sinotify::Notifier Event Spy <Sinotify::Event :path => '/tmp/sinotify_test', dir? => true, :etypes => [:delete]...
  etc.

    

== REQUIREMENTS:

* linux inotify dev libs
* cosell announcements framework gem

== INSTALL:

* Todo: install instruction
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

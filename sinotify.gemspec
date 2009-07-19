# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{sinotify}
  s.version = "0.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Steven Swerling"]
  s.date = %q{2009-07-18}
  s.description = %q{ALPHA Alert -- just uploaded initial release. 

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
  
(The 's' in 'sinotify' does in fact stand for 'suck.')}
  s.email = %q{sswerling@yahoo.com}
  s.extensions = ["ext/extconf.rb"]
  s.extra_rdoc_files = ["History.txt", "README.txt"]
  s.files = [".gitignore", "History.txt", "README.txt", "Rakefile", "examples/watcher.rb", "ext/Makefile", "ext/extconf.rb", "ext/src/inotify-syscalls.h", "ext/src/inotify.h", "ext/src/sinotify.c", "lib/sinotify.rb", "lib/sinotify/event.rb", "lib/sinotify/notifier.rb", "lib/sinotify/prim_event.rb", "lib/sinotify/watch.rb", "lib/sinotify_info.rb", "sinotify.gemspec", "spec/prim_notify_spec.rb", "spec/sinotify_spec.rb", "spec/spec_helper.rb"]
  s.homepage = %q{http://tab-a.slot-z.net}
  s.rdoc_options = ["--inline-source", "--main", "README.txt"]
  s.require_paths = ["lib", "ext"]
  s.rubyforge_project = %q{sinotify}
  s.rubygems_version = %q{1.3.3}
  s.summary = %q{ALPHA Alert -- just uploaded initial release}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<cosell>, [">= 0"])
      s.add_development_dependency(%q<bones>, [">= 2.4.0"])
    else
      s.add_dependency(%q<cosell>, [">= 0"])
      s.add_dependency(%q<bones>, [">= 2.4.0"])
    end
  else
    s.add_dependency(%q<cosell>, [">= 0"])
    s.add_dependency(%q<bones>, [">= 2.4.0"])
  end
end

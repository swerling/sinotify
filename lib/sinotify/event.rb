module Sinotify

  # 
  # Sinotify events are 'announced' by Cosell as they come in to the Notifier.
  # The list of event types is below. 
  #
  # Also see Sinotify::PrimEvent
  #
  # THIS EVENT CLASS DEVIATES FROM PRIMEVENT IN ONE SIGNIFICANT REGARD. Sinotify does not 
  # pass events about children of a given directory, only about the directory (or file) itself.
  # Example of difference: Let's say you
  #   1. create a directory called '/tmp/test'
  #   2. create a file called '/tmp/test/blah'
  #   3. You put a watch on the directory '/tmp/test'
  #   4. You do a 'rm -rf /tmp/test' (thus deleting both the file /tmp/test/blah and 
  #      the directory /tmp/test)
  #
  # In this example, Sinotify acts a little diffently from linux inotify. Linux inotify
  # would send a couple of delete events -- a :delete event for /tmp/test with the 'name'
  # of the event set to 'blah', indicating a file named 'blah' was deleted. Then, a :delete_self
  # event would be sent.
  #
  # In contrast, Sinotify::Notifier would send 2 events, both :delete events, 
  # one where the full path is '/tmp/test/blah', and one for '/tmp/test'. In general, all 
  # Sinotify events apply _to the thing that was altered_, not to its children. If there
  # is an event where this is not the case, it should be considered a bug. 
  #
  # If you want to work with an even notifier that works more like the low level linux inotify
  # (receiving both :delete and :delete_self), you will have to work directly with PrimNotifier and 
  # PrimEvent (along with there irritating synchronous event loop)
  #
  # Here is the list of possible events adapted from the definitions in [linux_src]/include/linux/inotify.h: 
  #
  #   File related:
  #     :access	# File was accessed 
  #     :modify # file modified
  #     :attrib # meta data changed
  #     :close_write   # writable file was closed
  #     :close_nowrite   # unwritable file was closed
  #     :open  # file was opened
  #     :moved_from # file moved from X
  #     :moved_to  # file moved to Y
  #     :create # file created
  #     :delete # file deleted
  #     :delete_self # self was deleted
  #     :move_self  # self was moved
  #
  #  File related helpers:
  #
  #     :close  # (close_write | close_nowrite)
  #     :move  # (moved_from | moved_to)
  #
  #  Misc events
  #
  #     :unmount # backing fs was unmounted
  #     :q_overflow # event queue overflowed
  #     :ignored  # file was ignored
  #     :mask_add # added to mask of already existing event
  #     :isdir # event occurred against dir
  #     :oneshot # only send event once
  #
  class Event

    attr_accessor :prim_event, :path, :timestamp, :is_dir

    # Given a prim_event, and the Watch associated with the event's watch descriptor,
    # return a Sinotify::Event. 
    def self.from_prim_event_and_watch(prim_event, watch)
      path = watch.path         # path for the watch associated w/ this even
      is_dir = watch.directory? # original watch was on a dir or a file?

      # This gets a little odd. The prim_event's 'name' field
      # will be nil if the change was to a directory itself, or if
      # the watch was on a file to begin with. However,
      # when a watch is on a dir, but the event occurs on a file in that dir
      # inotify sets the 'name' field to the file. :isdir will be in the etypes
      # if that file happens to be a subdir. Sinotify events do not
      # play this game, only sending events for the thing that was altered
      # in the first place. So right here is where we deduce if the 
      # event was _really_ on a file or a dir.
      unless prim_event.name.nil?
        path = File.join(path, prim_event.name) 
        is_dir = prim_event.etypes.include?(:isdir)
      end

      # is_dir must be passed along, since it may no longer exist (and thus cant be deduced later)
      # inotify prim_events to not retain enough information to make it possible to deduce the
      # original fullpath and whether it was a file or directory, so this info must be passed around.
      return Sinotify::Event.new(:prim_event => prim_event,
                                 :path => path,
                                 :timestamp => Time.now, # any way to get this from prim event?
                                 :is_dir => is_dir) 
    end

    def initialize(args={})
      args.each{|k,v| self.send("#{k}=",v)}
      @timestamp ||= Time.now

      # initialize a few variables just to shut up the ruby warnings
      @etypes = nil
    end

    def inspect_or_to_s(show_prim_event = false)
      prim_event = (show_prim_event)? ", :prim_event => #{self.prim_event.inspect}" : ''
      "<#{self.class} :path => '#{self.path}', dir? => #{self.directory?}, :etypes => #{self.etypes.inspect rescue 'could not determine'}#{prim_event}>"
    end
    def to_s; self.inspect_or_to_s(false); end
    def inspect; self.inspect_or_to_s(true); end

    # etype/mask functions delegated to prim_event, EXCEPT: when :delete_self is in 
    # the list, and path is a directory, change it to 'delete'. If you want
    # the etypes in the original prim_event, ask for event.prim_event.etypes
    def etypes
      if @etypes.nil?
        @etypes = self.prim_event.etypes

        # change :delete_self into :delete 
        if self.directory? and @etypes.include?(:delete_self)
          @etypes.delete(:delete_self)
          @etypes << :delete
        end

        # add :close if :close_write or :close_nowrite are there, but :close is not
        if @etypes.include?(:close_write) || @etypes.include?(:close_nowrite)
          (@etypes << :close) unless @etypes.include?(:close)
        end

      end
      @etypes
    end

    def directory?
      self.is_dir.eql?(true)
    end

    def has_etype? etype
      self.etypes.include?(etype)
    end

    def watch_descriptor
      self.prim_event.watch_descriptor
    end

  end

end

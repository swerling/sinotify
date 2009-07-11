module Sinotify

  # 
  # Sinotify events are triggered as they come in to the Notifier ('announced'
  # in the parlance of the Cosell announcement framework that sinotify uses).
  # Each event has the 'path' of the file or dir that was effected, the
  # timestamp of the event (generated in ruby, not at the primitive level), and
  # whether the event was on a file or a directory. Also available is the event
  # type, called the 'etype,' which can be :modify, :create, :delete, etc.  The
  # list of event types is below. 
  #
  # A Sinotify::Event does not perfectly model a linux inotify event. See
  # Sinotify::PrimEvent for that.
  #
  # This event class deviates from Sinotify::PrimEvent in one significant regard. Sinotify does not 
  # pass events about children of a given directory, it only passes events about the directory 
  # (or file) itself. That is _not_ to say you can't setup a recursive watch in the Notifier class,
  # just that _the event itself_ only pertains the the inode/file/directory being altered, not to 
  # its children. 
  #
  # This is perhaps best illustrated by an example. Let's say you
  #
  #   1. Create a directory called '/tmp/test'
  #   2. Create a file in '/tmp/test' called '/tmp/test/blah'
  #   3. You put a watch on the directory '/tmp/test'
  #   4. You then do a 'rm -rf /tmp/test' 
  #      (thus deleting both the file /tmp/test/blah AND the directory /tmp/test)
  #
  # In linux inotify, you would get two events in this scenario, _both_ on the
  # watch for the /tmp/test directory. One of the events would be a ':delete' event
  # (that is, the mask of the event would be equal to
  # Sinotify::PrimEvent::DELETE, or the 'etype' of the PrimEvent would equal
  # ':delete'), and the 'name' slot in the event would be 'blah.' This is your
  # cue that the event _really_ happened on a child of the thing being watched
  # ('/tmp/test'), not to the directory itself. Since you deleted both the file
  # and the directory with your 'rm -rf' command, another event would come in
  # of the etype :delete_self for the directory, and 'is_dir' would be in the
  # mask (ie. the mask would be Sinotify::PrimEvent::DELETE & Sinotify::PrimEvent::IS_DIR). 
  #
  # Sinotify events would be a bit different in the example above.
  # You would still get 2 events, but both would be :delete events, 
  # one where the 'path' is '/tmp/test', and the other where the 'path'
  # is '/tmp/test/blah'. In the case of the event for '/tmp/test', the call
  # to 'directory?' would return true.
  #
  # If you want to work with an event notifier that works more like the low level linux inotify
  # (receiving both :delete with name slot filled in and another event w/ :delete_self), 
  # you will have to work directly with PrimNotifier and PrimEvent (along with their irritating 
  # linux inotify-style blocking synchronous event loop)
  #
  # Here is the list of possible events adapted from the definitions
  # in [linux_src]/include/linux/inotify.h: 
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

    # a few attr declarations just so they show up in rdoc

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

    # The Sinotify::PrimEvent associated with this event (a straight 
    # wrapper around the linux inotify event)
    def prim_event; @prim_event; end

    # The full path of the file or directory on which the event happened
    def path; @path; end

    # when the event happened
    def timestamp; @timestamp; end


    def to_s; self.inspect_or_to_s(false); end
    def inspect; self.inspect_or_to_s(true); end

    # The etypes associated with this event (eg. :create, :modify, :delete, etc)
    def etypes
      # The etype/mask functions delegated to prim_event, EXCEPT: when :delete_self is in 
      # the list, and path is a directory, change it to 'delete'. If you want
      # the etypes in the original prim_event, ask for event.prim_event.etypes
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

    protected

      # :stopdoc:
      def inspect_or_to_s(show_prim_event = false)
        prim_event = (show_prim_event)? ", :prim_event => #{self.prim_event.inspect}" : ''
        "<#{self.class} :path => '#{self.path}', dir? => #{self.directory?}, :etypes => #{self.etypes.inspect rescue 'could not determine'}#{prim_event}>"
      end

      # :startdoc:
  end

end

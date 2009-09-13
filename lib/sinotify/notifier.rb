module Sinotify

  #
  #  Watch a directory or file for events like create, modify, delete, etc.
  #  (See Sinotify::Event for full list). 
  #
  #  See the synopsis section in the README.txt for example usage.
  #
  #
  class Notifier
    include Cosell

    attr_accessor :file_or_dir_name, :etypes, :recurse, :recurse_throttle, :logger

    #  Required Args
    #
    #    file_or_dir_name: the file/directory to watch
    #
    #  Options:
    #    :recurse => (true|false)
    #      whether to automatically create watches on sub directories
    #      default: true if file_or_dir_name is a directory, else false
    #      raises if true and file_or_dir_name is not a directory
    #
    #    :recurse_throttle => 
    #      When recursing, a background thread drills down into all the child directories
    #      creating notifiers on them. The recurse_throttle tells the notifier how far
    #      to recurse before sleeping for 0.1 seconds, so that drilling down does not hog
    #      the system on large directorie hierarchies.
    #      default is 10
    #
    #    :etypes => 
    #      which inotify file system event types to listen for (eg :create, :delete, etc)
    #      See docs for Sinotify::Event for list of event types.
    #      default is [:create, :modify, :delete]
    #      Use :all_events to trace everything (although this may be more than you bargained for).
    #
    #    :logger => 
    #      Where to log errors to. Default is Logger.new(STDOUT).
    #
    #    :announcement_throttle =>
    #      How many events can be announced at a time before the queue goes back to sleep for a cycle.
    #      (ie. Cosell's 'announcements_per_cycle')
    #
    #    :announcements_sleep_time =>
    #      How long the queue should sleep for before announcing the next batch of queued up 
    #      Sinotify::Events (ie. Cosell's 'sleep_time')
    #
    def initialize(file_or_dir_name, opts = {})

      initialize_cosell!  # init the announcements framework

      raise "Could not find #{file_or_dir_name}" unless File.exist?(file_or_dir_name)
      self.file_or_dir_name = file_or_dir_name

      # by default, recurse if directory?. If opts[:recurse] was true and passed in,
      # make sure the watch is on a directory
      self.recurse = opts[:recurse].nil?? self.on_directory? : opts[:recurse] 
      raise "Cannot recurse, #{file_or_dir_name} is not a directory" if self.recurse? && !self.on_directory?

      # how many directories at a time to register. 
      self.recurse_throttle = opts[:recurse_throttle] || 10 

      self.etypes = Array( opts[:etypes] || [:create, :modify, :delete] )
      validate_etypes!

      self.prim_notifier = Sinotify::PrimNotifier.new

      # setup async announcements queue (part of the Cosell mixin)
      @logger = opts[:logger] || Logger.new(STDOUT)
      sleep_time = opts[:announcements_sleep_time] || 0.05 
      announcement_throttle = opts[:announcement_throttle] || 50 
      self.queue_announcements!(:sleep_time => sleep_time, 
                                :logger => @logger,
                                :announcements_per_cycle => announcement_throttle)

      self.closed = false

      # initialize a few variables just to shut up the ruby warnings
      # Apparently the lazy init idiom using ||= is no longer approved of. Shame that.
      @spy_logger = nil
      @spy_logger_level = nil
      @watch_thread = nil
    end

    # Sugar. 
    #
    # Equivalent of calling cosell's
    #
    #    self.when_announcing(Sinotify::Event) do |event| 
    #      do_something_with_event(event) 
    #    end
    #
    # becomes
    #
    #    self.on_event { |event| do_something_with_event(event) }
    #
    # Since this class only announces one kind of event, it made sense to 
    # provide a more terse version of that statement.
    def on_event &block
      self.when_announcing(Sinotify::Event, &block)
    end
    
    # whether this watch is on a directory
    def on_directory?
      File.directory?(self.file_or_dir_name)
    end

    # Start watching for inotify file system events.
    def watch!
      raise "Cannot reopen an inotifier. Create a new one instead" if self.closed?
      self.add_all_directories_in_background
      self.start_prim_event_loop_thread
      return self
    end

    # Close this notifier. Notifiers cannot be reopened after close!. 
    def close!
      @closed = true
      self.remove_all_watches
      self.kill_queue! # cosell
    end

    # Log a message every time a prim_event comes in (will be logged even if it is considered 'noise'),
    # and log a message whenever an event is announced. Overrides Cosell's spy! method (and uses cosell's
    # spy! to log announced events).
    #
    # Options:
    #    :logger => The log to log to. Default is a logger on STDOUT
    #    :level => The log level to log with. Default is :info
    #    :spy_on_prim_events => Spy on PrimEvents (raw inotify events) too
    #
    def spy!(opts = {})
      self.spy_on_prim_events = opts[:spy_on_prim_events].eql?(true)
      self.spy_logger = opts[:logger] || Logger.new(STDOUT)
      self.spy_logger_level = opts[:level] || :info
      opts[:on] = Sinotify::Event
      opts[:preface_with] = "Sinotify::Notifier Event Spy"
      super(opts)
    end

    # Return a list of files/directories currently being watched. Will only contain one entry unless
    # this notifier was setup on a directory with the option :recurse => true.
    def all_directories_being_watched
      self.watches.values.collect{|w| w.path }.sort
    end

    def watches
      @watches ||= {}
    end

    # Whether this notifier watches all the files in all of the subdirectories
    # of the directory being watched.
    def recurse?
      self.recurse
    end

    def to_s
      "Sinotify::Notifier[#{self.file_or_dir_name}, :watches => #{self.watches.size}]"
    end

    protected

      #:stopdoc: 
 
      attr_accessor :spy_on_prim_events, :spy_logger, :spy_logger_level

      def validate_etypes!
        bad = self.etypes.detect{|etype| PrimEvent.mask_from_etype(etype).nil? }
        raise "Unrecognized etype '#{bad}'. Please see valid list in docs for Sinotify::Event" if bad
      end

      # some events we don't want to report (certain events are generated just from creating watches)
      def event_is_noise? prim_event, watch

        etypes_strings = prim_event.etypes.map{|e|e.to_s}.sort

        # the simple act of creating a watch causes these to fire"
        return true if ["close_nowrite", "isdir"].eql?(etypes_strings)
        return true if ["isdir", "open"].eql?(etypes_strings)
        return true if ["ignored"].eql?(etypes_strings)

        # If the event is on a subdir of the directory specified in watch, don't send it because
        # there should be another even (on the subdir itself) that comes through, and this one
        # will be redundant. 
        return true if ["delete", "isdir"].eql?(etypes_strings)

        return false
      end

      # Open up a background thread that adds all the watches on @file_or_dir_name and,
      # if @recurse is true, all of its subdirs.
      def add_all_directories_in_background
        @child_dir_thread = Thread.new do 
          begin
            self.add_watches! 
          rescue Exception => x
            log "Exception: #{x}, trace: \n\t#{x.backtrace.join("\n\t")}", :error 
          end
        end 
      end

      def add_watches!(fn = self.file_or_dir_name, throttle = 0)

        return if closed?
        if throttle.eql?(self.recurse_throttle)
          sleep 0.1
          throttle = 0
        end
        throttle += 1

        self.add_watch(fn)

        if recurse?
          Dir[File.join(fn, '/**')].each do |child_fn|
            next if child_fn.eql?(fn)
            self.add_watches!(child_fn, throttle) if File.directory?(child_fn)
          end
        end

      end

      def add_watch(fn)
        watch_descriptor = self.prim_notifier.add_watch(fn, self.raw_mask)
        # puts "ADDED WATCH: #{watch_descriptor} for #{fn}"
        remove_watch(watch_descriptor) # remove the existing, if it exists
        watch = Watch.new(:path => fn, :watch_descriptor => watch_descriptor)
        self.watches[watch_descriptor.to_s] = watch
      end

      # Remove the watch associated with the watch_descriptor passed in
      def remove_watch(watch_descriptor, prim_remove = false)
        if watches[watch_descriptor.to_s]
          #logger.debug "REMOVING WATCH: #{watch_descriptor}"
          self.watches.delete(watch_descriptor.to_s)

          # the prim_notifier will complain if we remove a watch on a deleted file,
          # since the watch will have automatically been removed already. Be default we
          # don't care, but if caller is sure there are some prim watches to clean
          # up, then they can pass 'true' for prim_remove. Another way to handle
          # this would be to just default to true and fail silently, but trying this
          # more conservative approach for now.
          self.prim_notifier.rm_watch(watch_descriptor.to_i) if prim_remove
        end
      end

      def remove_all_watches
        logger.debug "REMOVING ALL WATHCES"
        self.watches.keys.each{|watch_descriptor| self.remove_watch(watch_descriptor, true) }
        @watches = nil
      end

      def log(msg, level = :debug)
        puts(msg) unless [:debug, :info].include?(level)
        self.logger.send(level, msg) if self.logger
      end

      # Listen for linux inotify events, and as they come in
      #   1. adapt them into Sinotify::Event objects 
      #   2. 'announce' them using Cosell. 
      # By default, Cosell is setup to Queue the announcements in a bg thread.
      #
      # The references to two different logs in this method may be a bit confusing. The @spy_logger 
      # exclusively logs (spys on) events and announcements. The "log" method instead uses the @logger
      # and logs errors and exceptions. The @logger is defined when creating this object (using the :logger
      # option), and the @spy_logger is defined in the :spy! method.
      #
      def start_prim_event_loop_thread

        raise "Already watching!" unless @watch_thread.nil?

        @watch_thread = Thread.new do
          begin
            self.prim_notifier.each_event do |prim_event|
              watch = self.watches[prim_event.watch_descriptor.to_s]
              if event_is_noise?(prim_event, watch)
                self.spy_logger.debug("Sinotify::Notifier Spy: Skipping noise[#{prim_event.inspect}]") if self.spy_on_prim_events
              else
                spy_on_prim_event(prim_event)
                if watch.nil?
                  self.log "Could not determine watch from descriptor #{prim_event.watch_descriptor}, something is wrong. Event: #{prim_event.inspect}", :warn
                else
                  event = Sinotify::Event.from_prim_event_and_watch(prim_event, watch)
                  self.announce event
                  if event.has_etype?(:create) && event.directory?
                    Thread.new do 
                      # have to thread this because the :create event comes in _before_ the directory exists,
                      # and inotify will not permit a watch on a file unless it exists
                      sleep 0.1
                      self.add_watch(event.path)
                    end
                  end
                  # puts "REMOVING: #{event.inspect}, WATCH: #{self.watches[event.watch_descriptor.to_s]}" if event.has_etype?(:delete) && event.directory?
                  self.remove_watch(event.watch_descriptor) if event.has_etype?(:delete) && event.directory?
                  break if closed?
                end
              end
          end
          rescue Exception => x
            log "Exception: #{x}, trace: \n\t#{x.backtrace.join("\n\t")}", :error 
          end

          log "Exiting prim event loop thread for #{self}"
        end

      end

      def raw_mask
        if @raw_mask.nil?
          (self.etypes << :delete_self) if self.etypes.include?(:delete)
          @raw_mask = self.etypes.inject(0){|raw, etype| raw | PrimEvent.mask_from_etype(etype) }
        end
        @raw_mask
      end

      def spy_on_prim_event(prim_event)
        if self.spy_on_prim_events
          msg = "Sinotify::Notifier Prim Event Spy: #{prim_event.inspect}"
          self.spy_logger.send(@spy_logger_level, msg)
        end
      end

      # ruby gives warnings in verbose mode if you use attr_accessor to set these next few: 
      def prim_notifier; @prim_notifier; end
      def prim_notifier= x; @prim_notifier = x; end
      def watch_descriptor; @watch_descriptor; end
      def watch_descriptor= x; @watch_descriptor = x; end
      def closed?; @closed.eql?(true); end
      def closed= x; @closed = x; end

      #:startdoc: 
  end
end


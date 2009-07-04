module Sinotify

  #
  #  Sinotify::Notifier can be created on a file or directory. Inotify events are
  #  'announced' using a Cosell announcement queue.
  #
  #  Example usage:
  #
  #    # create a notifier on /tmp (and subdirs), and listen for :create, :modify, and :delete events. 
  #    # (The ability to spy and assign a handler block to announced events comes from the Cosell mixin)
  #
  #    notifier = Sinotify::Notifier.new('/tmp', :recurse => true, :etypes => [:create, :modify, :delete])
  #    notifier.spy!(Logger.new('/path/to/my/project/log/inotify_events.log'))
  #    notifier.when_announcing(Sinotify::Event) do |sinotify_event|
  #      puts "Event happened at #{sinotify_event.timestamp}, it is a #{sinotify_event.etype} on #{sinotify_event.full_path}"
  #    end
  #
  #  There are slight differences between Sinotify events and linux inotify events. Please see Sinotify::Event
  #  for details.
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
    #    :recurse_throttle => 
    #      When recursing, a background thread drills down into all the child directories
    #      creating notifiers on them. The recurse_throttle tells the notifier how far
    #      to recurse before sleeping for 0.1 seconds, so that drilling down does not hog
    #      the system on large directories.
    #      default is 10
    #    :etypes => 
    #      which inotify file system event types to listen for (eg :create, :delete, etc)
    #      See docs for Sinotify::Event for list of event types.
    #      default is :all_types
    #    :logger => 
    #      Where to log errors to. Default is Logger.new(STDOUT).
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

      self.etypes = Array(opts[:etypes] || :all_events)
      validate_etypes!

      self.prim_notifier = Sinotify::PrimNotifier.new

      # setup async announcements queue (part of the Cosell mixin)
      @logger = opts[:logger] || Logger.new(STDOUT)
      sleep_time = opts[:announcements_sleep_time] || 0.05 # undocumented for now
      announcements_per_cycle = opts[:announcements_per_cycle] || 50 # undocumented for now
      self.queue_announcements!(:sleep_time => sleep_time, 
                                :logger => opts[:logger], 
                                :announcements_per_cycle => announcements_per_cycle)

      self.closed = false

      # initialize a few variables just to shut up the ruby warnings
      # Apparently the lazy init idiom using ||= is no longer approved of. Shame that.
      @spy_logger = nil
      @spy_logger_level = nil
      @watch_thread = nil
    end
    
    def validate_etypes!
      bad = self.etypes.detect{|etype| PrimEvent.mask_from_etype(etype).nil? }
      raise "Unrecognized etype '#{bad}'. Please see valid list in docs for Sinotify::Event" if bad
    end

    def on_directory?
      File.directory?(self.file_or_dir_name)
    end

    def watch!
      raise "Already watching!" unless @watch_thread.nil?
      raise "Cannot reopen an inotifier. Create a new one instead" if self.closed?

      # add subdirectories in the background
      @child_dir_thread = Thread.new do 
        begin
          self.add_watches! 
        rescue Exception => x
          log "Exception: #{x}, trace: \n\t#{x.backtrace.join("\n\t")}", :error 
        end
      end 

      @watch_thread = Thread.new do
        begin
          self.prim_notifier.each_event do |prim_event|
            watch = self.watches[prim_event.watch_descriptor.to_s]
            if event_is_noise?(prim_event, watch)
              @spy_logger.debug("Sinotify::Notifier Spy: Skipping noise[#{prim_event.inspect}]") if @spy_logger
            else
              spy_on_event(prim_event)
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

        log "Exiting thread for #{self}"
      end

      return self
    end

    def recurse?
      self.recurse
    end

    def to_s
      "Sinotify::Notifier[#{self.file_or_dir_name}, :watches => #{self.watches.size}]"
    end

    def close!
      @closed = true
      self.remove_all_watches
    end

    def raw_mask
      @raw_mask ||= self.etypes.inject(0){|raw, etype| raw | PrimEvent.mask_from_etype(etype) }
    end

    def all_directories_being_watched
      self.watches.values.collect{|w| w.path }
    end

    def watches
      @watches ||= {}
    end

    # Log a message every time a prim_event comes in (will be logged even if it is considered 'noise'),
    # and log a message whenever an event is announced.
    # Options:
    #    :logger => The log to log to. Default is a logger on STDOUT
    #    :level => The log level to log with. Default is :info
    def spy!(opts = {})
      @spy_logger = opts[:logger] || Logger.new(STDOUT)
      @spy_logger_level = opts[:level] || :info
      opts[:on] = Sinotify::Event
      opts[:preface_with] = "Sinotify::Notifier Event Spy"
      super(opts)
    end

    protected

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
          # puts "REMOVING: #{watch_descriptor}"
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
        self.watches.keys.each{|watch_descriptor| self.remove_watch(watch_descriptor, true) }
      end

      def log(msg, level = :debug)
        puts(msg) unless [:debug, :info].include?(level)
        self.logger.send(level, msg) if self.logger
      end

      def spy_on_event(prim_event)
        if @spy_logger
          msg = "Sinotify::Notifier Prim Event Spy: #{prim_event.inspect}"
          @spy_logger.send(@spy_logger_level, msg)
        end
      end

      # ruby gives warnings in verbose mode if you use attr_accessor to set these next few: 
      def prim_notifier; @prim_notifier; end
      def prim_notifier= x; @prim_notifier = x; end
      def watch_descriptor; @watch_descriptor; end
      def watch_descriptor= x; @watch_descriptor = x; end
      def closed?; @closed.eql?(true); end
      def closed= x; @closed = x; end

  end
end


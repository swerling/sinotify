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
      self.queue_announcements!(:sleep_time => 0.1, :logger => opts[:logger], :announcements_per_cycle => 5)

      self.closed = false
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
            if event_is_noise?(prim_event)
              @spy_logger.debug("Sinotify::Notifier Spy: Skipping noise[#{prim_event.inspect}]") if @spy_logger
            else
              spy_on_event(prim_event)
              watch = self.watches[prim_event.watch_descriptor]
              if watch.nil?
                self.log "Could not determine watch from descriptor #{prim_event.watch_descriptor}, something is wrong. Event: #{prim_event.inspect}", :warn
              else
                event = Sinotify::Event.from_prim_event_and_watch(prim_event, watch)
                self.announce event
                self.add_watch(event.path) if event.has_etype?(:create) && event.directory?
                self.remove_watch(event.watch_descriptor) if event.has_etype?(:delete) && event.directory?
                break if closed?
              end
            end
        end
        rescue Exception => x
          log "Exception: #{x}, trace: \n\t#{x.backtrace.join("\n\t")}", :error 
        end

        puts "-----------exiting thread for #{self}"
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
      def event_is_noise? prim_event

        etypes_strings = prim_event.etypes.map{|e|e.to_s}.sort

        # the simple act of creating a watch causes these to fire"
        return true if ["close_nowrite", "isdir"].eql?(etypes_strings)
        return true if ["isdir", "open"].eql?(etypes_strings)
        return true if ["ignored"].eql?(etypes_strings)

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
        remove_watch(watch_descriptor) # remove the existing, if it exists
        watch = Watch.new(:path => fn, :watch_descriptor => watch_descriptor)
        self.watches[watch_descriptor] = watch
      end

      # Remove the watch associated with the watch_descriptor passed in
      def remove_watch(watch_descriptor)
        self.watches.delete(watch_descriptor)
        # the prim_notifier will complain if we remove a watch on a deleted file.
        # we don't care -- we're only removing the watch to be on the safe side
        self.prim_notifier.remove_watch(watch_descriptor) rescue nil
      end

      def remove_all_watches
        self.watches.keys.each{|watch_descriptor| self.remove_watch(fn) }
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


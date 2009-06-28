module Sinotify

  class Notifier
    include Cosell

    private

    attr_accessor :prim_notifier

    public

    attr_accessor :file_or_dir_name, :children


    @@notifiers = []

    def initialize(file_or_dir_name, opts = {})
      raise "Could not find #{file_or_dir_name}" unless File.exist(file_or_dir_name)

      @@file_or_dir_name << file_or_dir_name
      opts[:recurse] ||= true
      opts[:recurse_throttle] ||= 10 # how many directories at a time to register
      opts[:etypes] ||= [:all_events]
      (opts[:etypes] = [:all_events]) if opts[:etypes].include?(:all_events)

      @notifiers << self
      self
    end

    def self.all_notifiers
      @@notifiers
    end

    def self.close_all!
      @@notifiers.dup.each do |notifier|
        notifier.close
        @@notifiers.delete notifier
      end
    end

    def remove_listener(l)
      self.listeners.delete l
    end

    def clear_listeners!
      self.listeners = []
    end

    def listen!
      self.children.each{|c| c.listen! }
      self.each_event do |ev|
      end
    end

    def close!
      self.children.each{|c| c.close! }
      self.close
    end

  end

end


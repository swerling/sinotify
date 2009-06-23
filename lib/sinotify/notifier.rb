module Sinotify

  class Notifier
    attr_accessor :children

    @@notifiers = []

    def self.all_notifiers
      @@notifiers
    end

    def self.close_all_notifiers
      @@notifiers.dup.each do |notifier|
        notifier.close
        @@notifiers.delete notifier
      end
    end

    def add_listener(l, opts = {})
      opts[:recurse] ||= true
      opts[:recurse_throttle] ||= 10 # how many directories at a time to register
      opts[:etypes] ||= [:all_events]
      (opts[:etypes] = [:all_events]) if opts[:etypes].include?(:all_events)
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


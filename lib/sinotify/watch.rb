module Sinotify
  #
  # Just a little struct to describe a single inotifier watch
  # Note that the is_dir needs to be saved because we won't be
  # able to deduce that later if it was a deleted object.
  #
  class Watch 
    attr_accessor :is_dir, :path, :watch_descriptor
    def initialize(args={})
      args.each{|k,v| self.send("#{k}=",v)}
      @timestamp ||= Time.now
      @is_dir = File.directory?(path)
    end
    def directory?
      self.is_dir.eql?(true)
    end
    def to_s
      "Sinotify::Watch[:is_dir => #{is_dir}, :path => #{path}, :watch_descriptor => #{watch_descriptor}]"
    end
  end
end

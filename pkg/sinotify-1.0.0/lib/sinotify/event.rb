module Sinotify

  #
  # Sinotify::Event is a ruby wrapper for an inotify event
  # Use the Sinotify::Notifier to register to listen for these Events.
  #
  # Methods :name, :mask, and :wd defined in c lib
  #
  # For convenience, inotify masks are represented in the Event as an 'etype', 
  # which is just a ruby symbol corresponding to the mask. For instance, a mask
  # represented as Sinotify::MODIFY has an etype of :modify. You can still get
  # the mask if you want the 'raw' int mask value. In other words:
  # <pre>
  #      $ irb
  #      >> require 'sinotify'
  #      => true
  #      >> Sinotify::MODIFY
  #      => 2
  #      >> Sinotify::Event.etype_from_mask(Sinotify::MODIFY)
  #      => :modify
  #      >> Sinotify::Event.mask_from_etype(:modify)
  #      => 2
  # </pre>
  #
  # Event List as defined in sinotify.h (see 'man inotify' for details on these event types):
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

    # map the constants defined in the 'c' lib to ruby symbols
    @@mask_to_etype_map = {
      Sinotify::CREATE => :create,
      Sinotify::MOVE => :move,
      Sinotify::ACCESS => :access,
      Sinotify::MODIFY => :modify,
      Sinotify::ATTRIB => :attrib,
      Sinotify::CLOSE_WRITE => :close_write,
      Sinotify::CLOSE_NOWRITE => :close_nowrite,
      Sinotify::OPEN => :open,
      Sinotify::MOVED_FROM => :moved_from,
      Sinotify::MOVED_TO => :moved_to,
      Sinotify::DELETE => :delete,
      Sinotify::DELETE_SELF => :delete_self,
      Sinotify::MOVE_SELF => :move_self,
      Sinotify::UNMOUNT => :unmount,
      Sinotify::Q_OVERFLOW => :q_overflow,
      Sinotify::IGNORED => :ignored,
      Sinotify::CLOSE => :close,
      Sinotify::MASK_ADD => :mask_add,
      Sinotify::ISDIR => :isdir,
      Sinotify::ONESHOT => :oneshot,
      Sinotify::ALL_EVENTS => :all_events,
    }
    @@etype_to_mask_map = {}
    @@mask_to_etype_map.each{|k,v| @@etype_to_mask_map[v] = k}
    def self.etype_from_mask(mask)
      @@mask_to_etype_map[mask]
    end
    def self.mask_from_etype(etype)
      @@etype_to_mask_map[etype]
    end

    def self.all_etypes
      @@mask_to_etype_map.values.sort{|e1,e2| e1.to_s <=> e2.to_s}
    end

    # Return whether this event has etype specified
    def has_etype?(etype)
      mask_for_etype = self.class.mask_from_etype(etype)
      return (self.mask && mask_for_etype).eql?(self.mask)
    end

    def etypes
      self.class.all_etypes.select{|et| self.has_etype?(et)}
    end

    def watch_descriptor
      self.wd
    end

    def inspect
      "<#{self.class} :name => '#{self.name}', :etypes => #{self.etypes.inspect}, :mask => #{self.mask}, :watch_descriptor => #{self.watch_descriptor}>"
    end

  end

end


module Sinotify

  #
  # Sinotify::PrimEvent is a ruby wrapper for an inotify event
  # Use the Sinotify::PrimNotifier to register to listen for these Events.
  #
  # Most users of Sinotify will not want to listen for prim events, instead opting
  # to use a Sinotify::Notifier to listen for Sinotify::Events. See docs for those classes.
  #
  # Methods :name, :mask, and :wd defined in c lib
  #
  # For convenience, inotify masks are represented in the PrimEvent as an 'etype', 
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
  # See docs for Sinotify::Event class for full list of supported event symbol types and 
  # their symbols.
  #
  class PrimEvent

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
      Sinotify::ONLYDIR => :onlydir,
      Sinotify::DONT_FOLLOW => :dont_follow,
      Sinotify::ONESHOT => :oneshot,
      Sinotify::ALL_EVENTS => :all_events,
    }

    @@etype_to_mask_map = {}
    @@mask_to_etype_map.each{|k,v| @@etype_to_mask_map[v] = k}

#    def self.etype_from_mask(mask)
#      @@mask_to_etype_map[mask]
#    end

    def self.etype_from_mask(mask)
      @@mask_to_etype_map[mask]
    end

    def self.mask_from_etype(etype)
      @@etype_to_mask_map[etype]
    end

    def self.all_etypes
      @@mask_to_etype_map.values.sort{|e1,e2| e1.to_s <=> e2.to_s}
    end

    def name
      @name ||= self.prim_name
    end

    def wd
      @wd ||= self.prim_wd
    end

    def mask
      @mask ||= self.prim_mask
    end

    # When first creating a watch, inotify sends a bunch of events that have masks
    # don't seem to match up w/ any of the masks defined in inotify.h. Pass on those.
    def recognized?
      return !self.etypes.empty?
    end

    # Return whether this event has etype specified
    def has_etype?(etype)
      mask_for_etype = self.class.mask_from_etype(etype)
      return (self.mask & mask_for_etype).eql?(mask_for_etype)
    end

    def etypes
      @etypes ||= self.class.all_etypes.select{|et| self.has_etype?(et) }
    end

    def watch_descriptor
      self.wd
    end

    def inspect
      "<#{self.class} :name => '#{self.name}', :etypes => #{self.etypes.inspect}, :mask => #{self.mask.to_s(16)}, :watch_descriptor => #{self.watch_descriptor}>"
    end

  end

end


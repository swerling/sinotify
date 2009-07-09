module Sinotify

  #
  # Sinotify::PrimEvent is a ruby wrapper for an inotify event
  # Use the Sinotify::PrimNotifier to register to listen for these Events.
  #
  # Most users of Sinotify will not want to listen for prim events, instead opting
  # to use a Sinotify::Notifier to listen for Sinotify::Events. See docs for those classes.
  #
  # Methods :name, :mask, and :wd defined in sinotify.c
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
      Sinotify::PrimEvent::CREATE => :create,
      Sinotify::PrimEvent::MOVE => :move,
      Sinotify::PrimEvent::ACCESS => :access,
      Sinotify::PrimEvent::MODIFY => :modify,
      Sinotify::PrimEvent::ATTRIB => :attrib,
      Sinotify::PrimEvent::CLOSE_WRITE => :close_write,
      Sinotify::PrimEvent::CLOSE_NOWRITE => :close_nowrite,
      Sinotify::PrimEvent::OPEN => :open,
      Sinotify::PrimEvent::MOVED_FROM => :moved_from,
      Sinotify::PrimEvent::MOVED_TO => :moved_to,
      Sinotify::PrimEvent::DELETE => :delete,
      Sinotify::PrimEvent::DELETE_SELF => :delete_self,
      Sinotify::PrimEvent::MOVE_SELF => :move_self,
      Sinotify::PrimEvent::UNMOUNT => :unmount,
      Sinotify::PrimEvent::Q_OVERFLOW => :q_overflow,
      Sinotify::PrimEvent::IGNORED => :ignored,
      Sinotify::PrimEvent::CLOSE => :close,
      Sinotify::PrimEvent::MASK_ADD => :mask_add,
      Sinotify::PrimEvent::ISDIR => :isdir,
      Sinotify::PrimEvent::ONLYDIR => :onlydir,
      Sinotify::PrimEvent::DONT_FOLLOW => :dont_follow,
      Sinotify::PrimEvent::ONESHOT => :oneshot,
      Sinotify::PrimEvent::ALL_EVENTS => :all_events,
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


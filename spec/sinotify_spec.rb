
require File.join(File.dirname(__FILE__), %w[spec_helper])

class MockPrimEvent
  attr_accessor :etypes, :mask, :wd, :name
end

describe Sinotify do

  it "should properly create event mask from etypes" do
    notifier = Sinotify::Notifier.new('/tmp', :recurse => false, :etypes => [:create, :modify])
    notifier.raw_mask.should be_eql(Sinotify::CREATE | Sinotify::MODIFY)
    lambda{Sinotify::Notifier.new('/tmp', :recurse => false, :etypes => [:blah])}.should raise_error
  end

  it "should properly create Event from PrimEvent" do
    # mimic delete of a directory -- change :delete_self into :delete
    prim_event = MockPrimEvent.new
    prim_event.etypes = [:delete_self]
    watch = Sinotify::Watch.new(:is_dir => true, :path => '/tmp')
    event = Sinotify::Event.from_prim_event_and_watch(prim_event, watch)
    event.etypes.should be_include(:delete)
    event.etypes.should_not be_include(:delete_self)
  end

  it "should add watches for all child directories if recursive" do
  end

  it "should delete and close watches for all deleted files" do
  end

  it "should delete watches for on subdirectires when a parent directory is deleted" do
  end

  it "should delete and close watches on deleted directories" do
  end

  it "should exit and nil out watch_thread when closed" do
  end

  it "should close children when closed if recursive" do
  end

end

# EOF

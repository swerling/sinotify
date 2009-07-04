require File.join(File.dirname(__FILE__), %w[spec_helper])
require 'fileutils'

class MockPrimEvent
  attr_accessor :etypes, :mask, :wd, :name
end

describe Sinotify do

  # A lot of Sinotify work occurs in background threads (eg. adding watches, adding subdirectories),
  # so the tests may insert a tiny pause to allow the bg threads to do their thing before making
  # any assertions. 
  def tiny_pause!; sleep 0.05; end
  def pause!; sleep 0.5; end
  def big_pause!; sleep 1.5; end

  def reset_test_dir!
    raise 'not gonna happen' unless @test_root_dir =~ /\/tmp\//
    FileUtils.rm_rf(@test_root_dir)
    FileUtils.mkdir(@test_root_dir)
    ('a'..'z').each{|ch| FileUtils.mkdir(File.join(@test_root_dir, ch))}
    pause!
  end

  before(:each) do
    @test_root_dir = '/tmp/sinotifytestdir'
  end

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

    # :close should get added if event is :close_nowrite or :close_write
    prim_event = MockPrimEvent.new
    prim_event.etypes = [:close_nowrite]
    event = Sinotify::Event.from_prim_event_and_watch(prim_event, watch)
    event.etypes.should be_include(:close)
    prim_event = MockPrimEvent.new
    prim_event.etypes = [:close_write]
    event = Sinotify::Event.from_prim_event_and_watch(prim_event, watch)
    event.etypes.should be_include(:close)
  end

  it "should add watches for all child directories if recursive, and get rid of them all on close" do

    reset_test_dir!

    # make a watch, recurse false. There should only be one watch
    notifier = Sinotify::Notifier.new(@test_root_dir, :recurse => false).watch!

    tiny_pause!
    notifier.all_directories_being_watched.should be_eql([@test_root_dir])

    # make a watch, recurse TRUE. There should only be 27 watches (a-z, and @test_root_dir)
    spylog = Logger.new('/tmp/spy.log')
    spylog.level = Logger::DEBUG
    notifier = Sinotify::Notifier.new(@test_root_dir, :recurse => true).watch!
    notifier.spy!(:logger => spylog)
    #puts "------------#{notifier.all_directories_being_watched.inspect}"

    pause!
    notifier.all_directories_being_watched.size.should be_eql(27)

    # check a single announcement on a file in a subdir
    events = []
    test_fn = File.join(@test_root_dir, 'a', 'hi')
    notifier.when_announcing(Sinotify::Event) { |event|  events << event }
    FileUtils.touch test_fn
    pause!
    #puts events.map{|e|e.to_s}.join("\n")
    events.detect{|e| e.path.eql?(test_fn) && e.etypes.include?(:create) }.should_not be_nil
    events.detect{|e| e.path.eql?(test_fn) && e.etypes.include?(:open) }.should_not be_nil
    events.detect{|e| e.path.eql?(test_fn) && e.etypes.include?(:close_write) }.should_not be_nil

    events = []
    File.open(test_fn, 'a'){|f| f << 'ho'}
    pause!
    events.detect{|e| e.path.eql?(test_fn) && e.etypes.include?(:open) }.should_not be_nil
    events.detect{|e| e.path.eql?(test_fn) && e.etypes.include?(:modify) }.should_not be_nil
    events.detect{|e| e.path.eql?(test_fn) && e.etypes.include?(:close_write) }.should_not be_nil

    # quickly create and delete the file
    events = []
    FileUtils.rm test_fn
    tiny_pause!
    FileUtils.touch test_fn
    pause!
    events.detect{|e| e.path.eql?(test_fn) && e.etypes.include?(:delete) }.should_not be_nil
    events.detect{|e| e.path.eql?(test_fn) && e.etypes.include?(:create) }.should_not be_nil

  end

  it "should add a watch when a new subdirectory is created" do
    # setup
    reset_test_dir! # creates 27 directories, the root dir and 'a'...'z'
    subdir_a = File.join(@test_root_dir, 'a')
    events = []
    notifier = Sinotify::Notifier.new(@test_root_dir, :recurse => true).watch!
    notifier.spy!(:logger => spylog = Logger.new('/tmp/spy.log'))
    notifier.when_announcing(Sinotify::Event) { |event|  events << event }

    # one watch for the root and the 26 subdirs 'a'..'z'
    notifier.all_directories_being_watched.size.should be_eql(27) 

    # create a new subdir
    FileUtils.mkdir File.join(@test_root_dir, 'a', 'abc')
    big_pause! # takes a moment to sink in because the watch is added in a bg thread
    notifier.all_directories_being_watched.size.should be_eql(28) 
    pause!
  end

  it "should delete watches for on subdirectires when a parent directory is deleted" do

    # Setup (create the usual test dir and 26 subdirs, and an additional sub-subdir, and a file
    reset_test_dir! # creates the root dir and 'a'...'z'
    subdir_a = File.join(@test_root_dir, 'a')
    FileUtils.mkdir File.join(@test_root_dir, 'a', 'def')
    test_fn = File.join(subdir_a, 'hi')
    FileUtils.touch test_fn

    # Setup: create the notifier
    events = []
    notifier = Sinotify::Notifier.new(@test_root_dir, :recurse => true).watch!
    #notifier.spy!(:logger => Logger.new('/tmp/spy.log'))
    notifier.when_announcing(Sinotify::Event) { |event|  events << event }

    # first assert: all directories should have a watch
    pause!
    notifier.all_directories_being_watched.size.should be_eql(28) # all the directories should have watches


    # Should get delete events for the subdir_a and its file 'hi' when removing subdir_a.
    # There should be 26 watches left (after removing watches for subdir_a and its sub-subdir)
    FileUtils.rm_rf subdir_a
    pause!
    events.detect{|e| e.path.eql?(subdir_a) && e.directory? && e.etypes.include?(:delete) }.should_not be_nil
    events.detect{|e| e.path.eql?(test_fn) && !e.directory? && e.etypes.include?(:delete) }.should_not be_nil
    notifier.all_directories_being_watched.size.should be_eql(26)
  end

  it "should exit and nil out watch_thread when closed" do
    # really need this?
  end

  it "should close children when closed if recursive" do
  end

end

# EOF

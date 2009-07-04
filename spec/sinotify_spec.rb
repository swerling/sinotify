require File.join(File.dirname(__FILE__), %w[spec_helper])
require 'fileutils'

class MockPrimEvent
  attr_accessor :etypes, :mask, :wd, :name
end

#
#  WARNING: These tests are a bit brittle. They depend on events taking place in threads as a result
#  of filesytem events (inotify events). Sometimes the file system events dont come in as fast as
#  desirable for the test, or sometimes ruby threads themselves may not get scheduled fast enough.
#  If a test is failing on your system, it may start to succeed if you increase the values
#  in tiny_pause!, pause!, or big_pause! methods below. 
#
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

  it "should add watches for all child directories if recursive" do

    reset_test_dir!

    # make a watch, recurse false. There should only be one watch
    notifier = Sinotify::Notifier.new(@test_root_dir, :recurse => false).watch!

    tiny_pause!
    notifier.all_directories_being_watched.should be_eql([@test_root_dir])

    # make a watch, recurse TRUE. There should only be 27 watches (a-z, and @test_root_dir)
    notifier = Sinotify::Notifier.new(@test_root_dir, :recurse => true).watch!
    # notifier.spy!(:logger => Logger.new('/tmp/spy.log'))

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
    events.detect{|e| e.path.eql?(test_fn) && e.etypes.include?(:close) }.should_not be_nil

    events = []
    File.open(test_fn, 'a'){|f| f << 'ho'}
    pause!
    events.detect{|e| e.path.eql?(test_fn) && e.etypes.include?(:open) }.should_not be_nil
    events.detect{|e| e.path.eql?(test_fn) && e.etypes.include?(:modify) }.should_not be_nil
    events.detect{|e| e.path.eql?(test_fn) && e.etypes.include?(:close_write) }.should_not be_nil
    events.detect{|e| e.path.eql?(test_fn) && e.etypes.include?(:close) }.should_not be_nil

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
    # notifier.spy!(:logger => spylog = Logger.new('/tmp/spy.log'))
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
    # Setup (create the usual test dir and 26 subdirs, and an additional sub-subdir, and a file
    reset_test_dir! # creates the root dir and 'a'...'z'
    FileUtils.mkdir File.join(@test_root_dir, 'a', 'def')

    # Setup: create the notifier
    events = []
    notifier = Sinotify::Notifier.new(@test_root_dir, :recurse => true).watch!
    #notifier.spy!(:logger => Logger.new('/tmp/spy.log'))
    notifier.when_announcing(Sinotify::Event) { |event|  events << event }

    # first assert: all directories should have a watch
    pause!
    notifier.all_directories_being_watched.size.should be_eql(28) # all the directories should have watches

    notifier.close!
    notifier.all_directories_being_watched.size.should be_eql(0) # all watches should have been deleted
  end

  it "pound it" do
    # Setup (create the usual test dir and 26 subdirs, and an additional sub-subdir, and a file
    reset_test_dir! # creates the root dir and 'a'...'z'

    a_z = ('a'..'z').collect{|x|x}

    # Setup: create the notifier
    notifier = Sinotify::Notifier.new(@test_root_dir, 
                                      :announcements_sleep_time => 0.01,
                                      :announcements_per_cycle => 10000,
                                      :etypes => [:create, :modify, :delete, :close],
                                      :recurse => true).watch!
    #notifier.spy!(:logger => Logger.new('/tmp/spy.log'))
    creates = deletes = modifies = closes = 0
    notifier.when_announcing(Sinotify::Event) do |event|  
      creates += 1 if event.etypes.include?(:create) 
      deletes += 1 if event.etypes.include?(:delete) 
      modifies += 1 if event.etypes.include?(:modify) 
      closes += 1 if event.etypes.include?(:close) 
    end

    total_iterations = 1000
    dirs_used = []
    total_iterations.times do 
      sub_dir = File.join(@test_root_dir, a_z[rand(a_z.size)])
      dirs_used << sub_dir
      test_fn = File.join(sub_dir, "zzz#{rand(10000)}")
      FileUtils.touch test_fn
      File.open(test_fn, 'a'){|f| f << rand(1000).to_s }
      FileUtils.rm test_fn
    end
    dirs_used.uniq!
    puts "created and modified and deleted #{total_iterations} files in #{dirs_used.size} sub directories of #{@test_root_dir}"

    start_wait = Time.now

    # wait up to 15 seconds for all the create events to come through
    waits = 0
    puts "Waiting for events, will wait for up to 30 sec"
    while(creates < total_iterations) do
      sleep 1
      waits += 1
      raise "Tired of waiting for create events to reach #{total_iterations}, it is only at #{creates}" if waits > 30
    end
    puts "It took #{Time.now - start_wait} seconds for all the create/modify/delete/close events to come through"

    pause! # give it a tiny bit longer to let any remaining modify/delete events stragglers to come through

    puts "Ceates detected: #{creates}"
    puts "Deletes: #{deletes}"
    puts "Modifies: #{modifies}"
    puts "Closes: #{closes}"
    creates.should be_eql(total_iterations) 
    deletes.should be_eql(total_iterations) 
    modifies.should be_eql(total_iterations) 
    closes.should be_eql(2 * total_iterations) # should get a close both after the create and the modify
  end

end

# EOF

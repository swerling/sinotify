require File.join(File.dirname(__FILE__), 'spec_helper')
require 'fileutils'

#
# The tests for the inotify wrapper. 
# Mostly taken straight from ruby-inotify's tests, w/ some tweaks.
#
describe Sinotify::PrimNotifier do

  before(:each) do
    @inotify = Sinotify::PrimNotifier.new
  end

  it "should be able to create and remove a watch descriptor" do
    wd =  @inotify.add_watch("/tmp", Sinotify::CREATE)
    wd.class.should be_eql(Fixnum)
    wd.should_not be_eql(0)
    @inotify.rm_watch(wd).should be_true
  end

  it "should get events on watched directory and get name of altered file in watched directory" do
    test_fn = "/tmp/sinotify-test"
    FileUtils.rm_f test_fn 
    wd = @inotify.add_watch("/tmp", Sinotify::DELETE | Sinotify::CREATE)
    begin 
      FileUtils.touch test_fn
      @inotify.each_event do |ev|
        #puts "-----------#{ev.etypes.inspect}"
        ev.class.should be_eql(Sinotify::PrimEvent)
        ev.name.should be_eql('sinotify-test')
        ev.mask.should be_eql(Sinotify::CREATE)
        ev.has_etype?(:create).should be_true
        ev.etypes.size.should be_eql(1) 
        ev.inspect.should be_eql "<Sinotify::PrimEvent :name => 'sinotify-test', :etypes => [:create], :mask => 256, :watch_descriptor => 1>"
        break
      end
      FileUtils.rm_f test_fn
      @inotify.each_event do |ev|
        #puts "-----------#{ev.etypes.inspect}"
        ev.has_etype?(:delete).should be_true
        ev.etypes.size.should be_eql(1) 
        break
      end
    ensure
      @inotify.rm_watch(wd)
      FileUtils.rm_f test_fn 
    end
  end

  it "should get events on watched file" do
    test_fn = "/tmp/sinotify-test"
    FileUtils.touch test_fn 
    wd = @inotify.add_watch(test_fn, Sinotify::ATTRIB | Sinotify::DELETE | Sinotify::MODIFY)
    begin 
      FileUtils.touch test_fn
      @inotify.each_event do |ev|
        ev.name.should be_nil # name is only set when watching a directory
        ev.has_etype?(:attrib).should be_true
        break
      end

      File.open(test_fn, 'a'){|f| f << 'hi'}
      @inotify.each_event do |ev|
        ev.name.should be_nil # name is only set when watching a directory
        ev.has_etype?(:modify).should be_true
        break
      end

      FileUtils.rm_f test_fn
      @inotify.each_event do |ev|
        #puts "-----------#{ev.inspect}"
        # TODO: Look into this -- when deleting a file, it gets an event of type :attrib instead of :delete.
        # Is this a bug or something I am doing?
        # ev.has_etype?(:delete).should be_true
        break
      end

      # since the event is deleted, it should not be possible to remove the watch
      lambda{@inotify.rm_watch(wd)}.should raise_error

    ensure
      @inotify.rm_watch(wd) rescue nil
      FileUtils.rm_f test_fn 
    end
  end

  protected

    def little_bench(msg, &block)
      start = Time.now
      result = block.call
      puts "#{msg}: #{Time.now - start} sec"
      return result
    end
end

# EOF


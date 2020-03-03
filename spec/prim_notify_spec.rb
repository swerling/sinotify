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
    wd =  @inotify.add_watch("/tmp", Sinotify::PrimEvent::CREATE)
    #wd.class.should be_eql(Fixnum)
    #wd.should_not be_eql(0)
    #@inotify.rm_watch(wd).should be_true
    expect(wd.class).to eq(Fixnum)
    expect(wd).not_to eq(0)
    expect(@inotify.rm_watch(wd)).to eq(true)
  end

  it "should get events on watched directory and get name of altered file in watched directory" do
    test_fn = "/tmp/sinotify-test"
    FileUtils.rm_f test_fn
    wd = @inotify.add_watch("/tmp", Sinotify::PrimEvent::DELETE | Sinotify::PrimEvent::CREATE)
    begin
      FileUtils.touch test_fn
      @inotify.each_event do |ev|
        #puts "-----------#{ev.etypes.inspect}"
        expect(ev.class).to eq(Sinotify::PrimEvent)
        expect(ev.class).to eq(Sinotify::PrimEvent)
        expect(ev.name).to eq('sinotify-test')
        expect(ev.mask).to eq(Sinotify::PrimEvent::CREATE)
        expect(ev.has_etype?(:create)).to eq(true)
        expect(ev.etypes.size).to eq(1)
        expect(ev.inspect).to eq("<Sinotify::PrimEvent :name => 'sinotify-test', :etypes => [:create], :mask => 100, :watch_descriptor => 1>")
        break
      end
      FileUtils.rm_f test_fn
      @inotify.each_event do |ev|
        #puts "-----------#{ev.etypes.inspect}"
        expect(ev.has_etype?(:delete)).to eq(true)
        expect(ev.etypes.size).to eq(1)
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
    wd = @inotify.add_watch(test_fn, Sinotify::PrimEvent::ATTRIB | Sinotify::PrimEvent::DELETE | Sinotify::PrimEvent::MODIFY)
    begin
      FileUtils.touch test_fn
      @inotify.each_event do |ev|
        expect(ev.name).to be_nil # name is only set when watching a directory
        expect(ev.has_etype?(:attrib)).to eq(true)
        break
      end

      File.open(test_fn, 'a'){|f| f << 'hi'}
      @inotify.each_event do |ev|
        expect(ev.name).to be_nil # name is only set when watching a directory
        expect(ev.has_etype?(:modify)).to eq(true)
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


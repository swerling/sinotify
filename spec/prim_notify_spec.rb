require File.join(File.dirname(__FILE__), 'spec_helper')
require 'fileutils'

#
# The tests
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

  it "should get create event when creating file in watched directory" do
    test_fn = File.join("/tmp/sinotify-test")
    FileUtils.rm_f test_fn 
    wd = @inotify.add_watch("/tmp", Sinotify::CREATE)
    begin 
      FileUtils.touch test_fn
      @inotify.each_event do |ev|
        ev.class.should be_eql(Sinotify::Event)
        ev.name.should be_eql('sinotify-test')
        ev.mask.should be_eql(Sinotify::CREATE)
        ev.inspect.should be_eql "<Sinotify::Event :name => 'sinotify-test', :etypes => [:create], :mask => 256, :watch_descriptor => 1>"
        break
      end
    ensure
      @inotify.rm_watch(wd)
      FileUtils.rm_f test_fn 
    end
  end

  it "should create correct etype" do
    test_fn = File.join("/tmp/sinotify-test")
    FileUtils.rm_f test_fn 
    wd = @inotify.add_watch("/tmp", Sinotify::CREATE)
    begin 
      FileUtils.touch test_fn
      @inotify.each_event do |ev|
        ev.has_etype?(:create).should be_true
        ev.etypes.size.should be_eql(1) 
        break
      end
    ensure
      @inotify.rm_watch(wd)
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


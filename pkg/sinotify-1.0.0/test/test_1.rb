require 'test/unit'
require 'sinotify'

class Test1 < Test::Unit::TestCase

  def setup
    @inotify = Sinotify::Notifier.new
  end

  def test_create_notifier
    assert_equal(Sinotify::Notifier, @inotify.class)
  end

  def test_add_watch
    assert(@inotify.add_watch("/tmp", Sinotify::CREATE))
  end

  def test_create_watch_descriptor
    wd = @inotify.add_watch("/tmp", Sinotify::CREATE)
    assert_equal(Fixnum, wd.class)
    assert(@inotify.rm_watch(wd))
  end

  def test_notification
    @inotify.add_watch("/tmp", Sinotify::CREATE)
    begin 
      File.open(File.join("/tmp", "ruby-inotify-test-4"), 'w')
      @inotify.each_event do |ev|
        assert_equal(ev.class, Sinotify::Event)
        assert_equal(ev.name, "ruby-inotify-test-4")
        assert_equal(ev.mask, Sinotify::CREATE)
        assert_equal(ev.inspect, "<Sinotify::Event :name => 'ruby-inotify-test-4', :etypes => [:create], :mask => 256, :watch_descriptor => 1>")
        break
      end
    ensure
      File.unlink(File.join("/tmp", "ruby-inotify-test-4"))
    end
  end

  def test_etypes
    @inotify.add_watch("/tmp", Sinotify::CREATE)
    begin 
      File.open(File.join("/tmp", "ruby-inotify-test-4"), 'w')
      @inotify.each_event do |ev|
        assert ev.has_etype?(:create)
        assert_equal 1, ev.etypes.size
        break
      end
    ensure
      File.unlink(File.join("/tmp", "ruby-inotify-test-4"))
    end
  end

  def teardown
    @inotify.close
  end

end

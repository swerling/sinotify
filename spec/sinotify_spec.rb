
require File.join(File.dirname(__FILE__), %w[spec_helper])

describe Sinotify do
  it "should properly create event mask from etypes" do
  end
  it "should properly create Event from PrimEvent" do
  end
  it "should turn :delete_self into :delete for directories" do
  end
  it "should properly assign the is_dir attribute on all events" do
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

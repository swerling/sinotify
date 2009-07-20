# Look in the tasks/setup.rb file for the various options that can be
# configured in this Rakefile. The .rake files in the tasks directory
# are where the options are used.

begin
  require 'bones'
  Bones.setup
rescue LoadError
  begin
    load 'tasks/setup.rb'
  rescue LoadError
    raise RuntimeError, '### please install the "bones" gem ###'
  end
end

#ensure_in_path 'lib'

require File.join(File.dirname(__FILE__), 'lib/sinotify_info')

# bones gem settings
PROJ.name = 'sinotify'
PROJ.authors = 'Steven Swerling'
PROJ.email = 'sswerling@yahoo.com'
PROJ.url = 'http://tab-a.slot-z.net'
PROJ.version = Sinotify::VERSION
PROJ.rubyforge.name = 'sinotify'
PROJ.gem.extentions = FileList['ext/**/extconf.rb']
PROJ.gem.dependencies = ['cosell']
PROJ.spec.opts << '--color'
PROJ.rdoc.opts = ["--inline-source"]
PROJ.rdoc.exclude = ["^tasks/setup\.rb$", "\.[ch]$"]





require 'fileutils'
def this_dir; File.join(File.dirname(__FILE__)); end
def doc_dir; File.join(this_dir, 'rdoc'); end
def tab_a_doc_dir; File.join(this_dir, '../tab-a/public/sinotify/rdoc'); end

task :default => 'spec:run'
task :myclobber => [:clobber] do
  mydir = File.join(File.dirname(__FILE__))
  sh "rm -rf #{File.join(mydir, 'pkg')}"
  sh "rm -rf #{File.join(mydir, 'doc')}"
  sh "rm -rf #{File.join(mydir, 'rdoc')}"
  sh "rm -rf #{File.join(mydir, 'ext/*.log')}"
  sh "rm -rf #{File.join(mydir, 'ext/*.o')}"
  sh "rm -rf #{File.join(mydir, 'ext/*.so')}"
  sh "rm -rf #{File.join(mydir, 'ext/Makefile')}"
  sh "rm -rf #{File.join(mydir, 'ext/Makefile')}"
end
task :mypackage => [:myclobber] do
  Rake::Task['gem:package'].invoke
end
task :mydoc => [:myclobber] do
  FileUtils.rm_f doc_dir()
  sh "cd #{this_dir()} && rdoc -o rdoc --inline-source --format=html -T hanna README.rdoc lib/**/*.rb" 
end
task :taba => [:mydoc] do
  this_dir = File.join(File.dirname(__FILE__))
  FileUtils.rm_rf tab_a_doc_dir
  FileUtils.cp_r doc_dir, tab_a_doc_dir
end
task :mygemspec => [:myclobber] do
  Rake::Task['gem:spec'].invoke
end

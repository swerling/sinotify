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

task :default => 'spec:run'
namespace :my do
  namespace :gem do
    task :package => [:clobber] do
      sh "rm -rf #{File.join(File.dirname(__FILE__), 'pkg')}"
      sh "rm -rf #{File.join(File.dirname(__FILE__), 'doc')}"
      sh "rm -rf #{File.join(File.dirname(__FILE__), 'ext/*.log')}"
      sh "rm -rf #{File.join(File.dirname(__FILE__), 'ext/*.o')}"
      sh "rm -rf #{File.join(File.dirname(__FILE__), 'ext/*.so')}"
      Rake::Task['gem:package'].invoke
    end
  end
end


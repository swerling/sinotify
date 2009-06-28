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

ensure_in_path 'lib'
require 'sinotify'

task :default => 'spec:run'

PROJ.name = 'sinotify'
PROJ.authors = 'Steven Swerling'
PROJ.email = 'sswerling@yahoo.com'
PROJ.url = 'http://tab-a.slot-z.net'
PROJ.version = Sinotify::VERSION
PROJ.rubyforge.name = 'sinotify'
PROJ.gem.extentions = FileList['ext/**/extconf.rb']
PROJ.gem.dependencies = ['cosell']
PROJ.spec.opts << '--color'

# EOF

require "bundler/gem_tasks"

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = GrassGis::VERSION

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "GrassGis #{version}"
  rdoc.main = "README.md"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
  rdoc.markup = 'markdown' if rdoc.respond_to?(:markup)
end

task :default => :test

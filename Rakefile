require 'rubocop/rake_task'
require 'rspec/core/rake_task'

Rubocop::RakeTask.new
RSpec::Core::RakeTask.new(:rspec)

task :spec => [:rubocop, :rspec]
task :default => [:spec]
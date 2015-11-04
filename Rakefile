require 'rubygems'
require 'bundler/setup'
require 'bundler/gem_tasks'

require 'rspec/core/rake_task'

namespace :spec do
  RSpec::Core::RakeTask.new(:file) do |t|
    t.pattern = ENV['SPEC_FILE']
  end

  RSpec::Core::RakeTask.new(:unit) do |t|
    t.pattern = 'spec/unit/**/*_spec.rb'
  end

  RSpec::Core::RakeTask.new(:functional) do |t|
    t.pattern = 'spec/functional/**/*_spec.rb'
  end

  task :all => [:unit, :functional]
end

task :default  => 'spec:all'

task :clean do
  system "rm -rf pkg/*"
end

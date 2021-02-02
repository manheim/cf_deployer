require 'rubygems'
require 'bundler/setup'
require 'bundler/gem_tasks'

require 'rspec/core/rake_task'

namespace :spec do
  RSPEC_OPTS = ["--format", "documentation", "--format", "html", "--out", "spec_result.html", "--colour"]

  RSpec::Core::RakeTask.new(:file) do |t|
    t.rspec_opts = RSPEC_OPTS
    t.pattern = ENV['SPEC_FILE']
  end

  RSpec::Core::RakeTask.new(:unit) do |t|
    t.rspec_opts = RSPEC_OPTS
    t.pattern = 'spec/unit/**/*_spec.rb'
  end

  RSpec::Core::RakeTask.new(:functional) do |t|
    t.rspec_opts = RSPEC_OPTS
    t.pattern = 'spec/functional/**/*_spec.rb'
  end

  RSpec::Core::RakeTask.new(:aws_call_count) do |t|
    t.rspec_opts = RSPEC_OPTS
    t.pattern = 'spec/aws_call_count/**/*_spec.rb'
  end

  task :all => [:unit, :functional, :aws_call_count]
end

task :default  => 'spec:all'

task :clean do
  system "rm -rf pkg/*"
end

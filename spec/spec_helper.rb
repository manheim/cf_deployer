require_relative '../lib/cf_deployer'
Dir.glob("#{File.dirname File.absolute_path(__FILE__)}/fakes/*.rb") { |file| require file }

CfDeployer::Log.log.outputters = nil

RSPEC_LOG = Logger.new(STDOUT)
RSPEC_LOG.level = Logger::WARN

if ENV['DEBUG']
  RSPEC_LOG.level = Logger::DEBUG
  # AWS.config :logger => RSPEC_LOG
end

def puts *args

end

def ignore_errors
  yield
rescue => e
  RSPEC_LOG.debug "Intentionally ignoring error: #{e.message}"
end

RSpec.configure do |config|
  # These two settings work together to allow you to limit a spec run
  # to individual examples or groups you care about by tagging them with
  # `:focus` metadata. When nothing is tagged with `:focus`, all examples
  # get run.
  config.filter_run :focus
  config.run_all_when_everything_filtered = true
end

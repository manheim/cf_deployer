require_relative '../lib/cf_deployer'
Dir.glob("#{File.dirname File.absolute_path(__FILE__)}/fakes/*.rb") { |file| require file }

CfDeployer::Log.log.outputters = nil

RSPEC_LOG = Logger.new(STDOUT)
RSPEC_LOG.level = Logger::INFO

def puts *args

end

def ignore_errors
  yield
rescue => e
  RSPEC_LOG.debug "Intentionally ignoring error: #{e.message}"
end

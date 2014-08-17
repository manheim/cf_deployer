require_relative '../lib/cf_deployer'
Dir.glob("#{File.dirname File.absolute_path(__FILE__)}/fakes/*.rb") { |file| require file }

CfDeployer::Log.log.outputters = nil

def puts *args

end


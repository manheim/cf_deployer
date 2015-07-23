# -*- encoding: utf-8 -*-
require File.expand_path('../lib/cf_deployer/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Jame Brechtel", "Peter Zhao", "Patrick McFadden", "Rob Sweet"]
  gem.email         = ["jbrechtel@gmail.com", "peter.qs.zhao@gmail.com", "pemcfadden@gmail.com", "rob@ldg.net"]
  gem.description   = %q{For automatic blue green deployment flow on CloudFormation.}
  gem.summary       = %q{Support multiple components deployment using CloudFormation templates with multiple blue green strategies.}
  gem.homepage      = "http://github.com/manheim/cf_deployer"
  gem.license = 'MIT'

  gem.add_runtime_dependency 'aws-sdk','1.44.0'
  gem.add_runtime_dependency 'log4r'
  gem.add_runtime_dependency 'thor'
  gem.add_runtime_dependency 'rainbow'
  gem.add_runtime_dependency 'diffy'
  gem.add_development_dependency 'yard', '~> 0.8.7.6'
  gem.add_development_dependency 'pry', '~> 0.10.1'
  gem.add_development_dependency 'rspec', '2.14.1'
  gem.add_development_dependency 'rake', '~> 10.3.0'

  gem.files         = `git ls-files`.split($\).reject {|f| f =~ /^samples\// }
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "cf_deployer"
  gem.require_paths = ["lib"]
  gem.version       = CfDeployer::VERSION
end

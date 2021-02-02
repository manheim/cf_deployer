# -*- encoding: utf-8 -*-
require File.expand_path('../lib/cf_deployer/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Jame Brechtel", "Peter Zhao", "Patrick McFadden", "Rob Sweet"]
  gem.email         = ["jbrechtel@gmail.com", "peter.qs.zhao@gmail.com", "pemcfadden@gmail.com", "rob@ldg.net"]
  gem.description   = %q{For automatic blue green deployment flow on CloudFormation.}
  gem.summary       = %q{Support multiple components deployment using CloudFormation templates with multiple blue green strategies.}
  gem.homepage      = "http://github.com/manheim/cf_deployer"
  gem.license = 'MIT'

  gem.add_runtime_dependency 'json','~> 2.5'
  gem.add_runtime_dependency 'aws-sdk-autoscaling', '~> 1.53'
  gem.add_runtime_dependency 'aws-sdk-core','~> 3.111'
  gem.add_runtime_dependency 'aws-sdk-cloudformation', '~> 1.46'
  gem.add_runtime_dependency 'aws-sdk-ec2', '~> 1.221'
  gem.add_runtime_dependency 'aws-sdk-elasticloadbalancing', '~> 1.29'
  gem.add_runtime_dependency 'aws-sdk-route53', '~> 1.45'
  gem.add_runtime_dependency 'log4r'
  gem.add_runtime_dependency 'thor'
  gem.add_runtime_dependency 'rainbow'
  gem.add_runtime_dependency 'diffy'
  gem.add_development_dependency 'yard', '~> 0.9'
  gem.add_development_dependency 'pry', '~> 0.13'
  gem.add_development_dependency 'rspec', '3.10'
  gem.add_development_dependency 'rake', '~> 13.0'
  gem.add_development_dependency 'webmock', '~> 3.11'
  gem.add_development_dependency 'vcr', '~> 6.0'

  gem.files         = `git ls-files`.split($\).reject {|f| f =~ /^samples\// }
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "cf_deployer"
  gem.require_paths = ["lib"]
  gem.version       = CfDeployer::VERSION
end

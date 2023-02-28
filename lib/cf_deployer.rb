require 'digest'
require 'set'
require 'time'
require 'json'
require 'yaml'
require 'timeout'
require 'aws-sdk-autoscaling'
require 'aws-sdk-ec2'
require 'aws-sdk-core'
require 'aws-sdk-cloudformation'
require 'aws-sdk-elasticloadbalancing'
require 'aws-sdk-route53'
require 'erb'
require 'fileutils'
require 'log4r'
require 'pp'
require 'forwardable'

require_relative 'cf_deployer/application_error'
require_relative 'cf_deployer/cli'
require_relative 'cf_deployer/application'
require_relative 'cf_deployer/aws_constants'
require_relative 'cf_deployer/component'
require_relative 'cf_deployer/config_loader'
require_relative 'cf_deployer/config_validation'
require_relative 'cf_deployer/stack'
require_relative 'cf_deployer/version'
require_relative 'cf_deployer/status_presenter'
require_relative 'cf_deployer/deployment_strategy/base'
require_relative 'cf_deployer/deployment_strategy/blue_green'
require_relative 'cf_deployer/deployment_strategy/auto_scaling_group_swap'
require_relative 'cf_deployer/deployment_strategy/cname_swap'
require_relative 'cf_deployer/deployment_strategy/create_or_update'
require_relative 'cf_deployer/driver/auto_scaling_group'
require_relative 'cf_deployer/driver/cloud_formation_driver'
require_relative 'cf_deployer/driver/dry_run'
require_relative 'cf_deployer/driver/elb_driver'
require_relative 'cf_deployer/driver/instance'
require_relative 'cf_deployer/driver/route53_driver'
require_relative 'cf_deployer/driver/verisign_driver'
require_relative 'cf_deployer/logger'
require_relative 'cf_deployer/hook'
require_relative 'cf_deployer/defaults'

module CfDeployer

  aws_config = Seahorse::Client::Configuration.new
  aws_config.add_option(:max_retries, 20)

  def self.config opts
    config = self.parseconfig opts, false
    config[:components].each do |component, c_hash|
      c_hash.delete :defined_parameters
    end
    puts config.select { |k,v| [:components, :environments, :environment, :application, :'config-file'].include? k.to_sym }.to_yaml
  end

  def self.deploy opts
    config = self.parseconfig opts
    Application.new(config).deploy
  end

  def self.runhook opts
    config = self.parseconfig opts
    Application.new(config).run_hook opts[:component].first, opts[:hook_name]
  end

  def self.destroy opts
    config = self.parseconfig opts, false
    Application.new(config).destroy
  end

  def self.json opts
    config = self.parseconfig opts, false
    Application.new(config).json
  end

  def self.diff opts
    config = self.parseconfig opts, false
    Application.new(config).diff
  end

  def self.status opts
    config = self.parseconfig opts, false
    status_info = Application.new(config).status opts[:component].first, opts[:verbosity]
    presenter = CfDeployer::StatusPresenter.new status_info, opts[:verbosity]

    puts opts[:'output-format'] == 'json' ? presenter.to_json : presenter.output
  end

  def self.switch opts
    config = self.parseconfig opts, false
    Application.new(config).switch
  end

  def self.kill_inactive opts
    config = self.parseconfig opts, false
    Application.new(config).kill_inactive
  end

  private

  def self.parseconfig options, validate_inputs = true
    Aws.config.update({region: options[:region]}) if options[:region]
    options[:cli_overrides] = {:settings => options.delete(:settings), :inputs => options.delete(:inputs)}
    config = ConfigLoader.new.load options
    ConfigValidation.new.validate config, validate_inputs
    config
  end

end

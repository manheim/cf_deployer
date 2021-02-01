require 'thor'

module CfDeployer
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    class_option :'config-file', :aliases => '-f', :desc => "cf_deployer config file", :default => 'config/cf_deployer.yml'
    class_option :'log-level',   :aliases => '-l', :desc => "logging level", :enum => %w(info debug aws-debug), :default => 'info'
    class_option :'dry-run',     :aliases => '-d', :desc => "Say what we would do but don't actually make changes to anything", :banner => ''
    class_option :settings,      :aliases => '-s', :type => :hash, :desc =>  "key:value pair to overwrite setting in config"
    class_option :inputs,        :aliases => '-i', :type => :hash, :desc => "key:value pair to overwrite in template inputs"
    class_option :region,        :aliases => '-r', :desc => "Amazon region", :default => 'us-east-1'

    desc "deploy [ENVIRONMENT] [COMPONENT]\t", 'Deploy the specified components'
    def deploy environment, component = nil
      prep_for_action :deploy, environment, component
      CfDeployer.deploy merged_options
    end

    desc "runhook [ENVIRONMENT] [COMPONENT] [HOOK_NAME]\t", 'Run the specified hook'
    def runhook environment, component, hook_name
      @hook_name = hook_name.to_sym
      prep_for_action :runhook, environment, component
      CfDeployer.runhook merged_options
    end

    desc "destroy [ENVIRONMENT] [COMPONENT]\t", 'Destroy the specified environment/component'
    def destroy environment, component = nil
      prep_for_action :destroy, environment, component
      CfDeployer.destroy merged_options
    end

    desc "config [ENVIRONMENT]", 'Show parsed config'
    def config environment
      prep_for_action :config, environment
      CfDeployer.config merged_options
    end

    desc "diff [ENVIRONMENT] [COMPONENT]", 'Show a diff between the template of the active stack and the parsed CloudFormation JSON for the target component'
    def diff environment, component = nil
      prep_for_action :diff, environment, component
      CfDeployer.diff merged_options
    end

    desc "json [ENVIRONMENT] [COMPONENT]", 'Show parsed CloudFormation JSON for the target component'
    def json environment, component = nil
      prep_for_action :json, environment, component
      CfDeployer.json merged_options
    end

    desc 'status [ENVIRONMENT] [COMPONENT]', 'Show the status of the specified Cloud Formation components specified in your yml'
    method_option :verbosity,  :aliases => '-v', :desc => 'Verbosity level',  :enum => ['stacks','instances','all'], :default => 'instances'
    method_option :'output-format', :aliases => '-o', :enum => ['human','json'], :default => 'human', :desc => 'Output format'
    def status environment, component = nil
      prep_for_action :status, environment, component
      CfDeployer.status merged_options
    end

    desc 'kill_inactive [ENVIRONMENT] [COMPONENT]', 'Destroy the inactive stack for a given component/environment'
    def kill_inactive environment, component
      prep_for_action :kill_inactive, environment, component
      CfDeployer.kill_inactive merged_options
    end

    desc 'switch [ENVIRONMENT] [COMPONENT]', 'Switch active and inactive stacks'
    def switch environment, component
      prep_for_action :switch, environment, component
      CfDeployer.switch merged_options
    end

    no_commands do

      def prep_for_action action, environment, component = nil
        no_component_required_actions = [:config, :status]
        if environment == 'help' || (no_component_required_actions.include? action && component == nil)
          self.class.command_help shell, action
          exit 0
        end
        @environment = environment
        @component = [component].compact
        validate_cli options
        set_log_level
        detect_dry_run
      end

      def merged_options
        the_merge_options = {:environment => @environment, :component => @component}
        the_merge_options[:hook_name] = @hook_name if @hook_name
        symbolize_all_keys options.merge(the_merge_options)
      end

      def set_log_level
        if options[:'log-level'] == 'aws-debug'
          CfDeployer::Log.level = 'debug'
          # AWS.config :logger => Logger.new($stdout)
        else
          # CfDeployer::Log.level = options[:'log-level']
        end
      end

      def detect_dry_run
        CfDeployer::Driver::DryRun.enable if options[:'dry-run']
      end

      def validate_cli cli_options
        unless File.file?(options[:'config-file'])
          error_exit "ERROR:  #{options[:'config-file']} is not a file."
        end
        error_exit "ERROR:  No environment specified!" unless @environment
      end

      def symbolize_all_keys(hash)
        return hash unless hash.is_a?(Hash)
        hash.inject({}){|memo,(k,v)|  memo.delete(k); memo[k.to_sym] = symbolize_all_keys(v); memo}
      end

      def error_exit message
        puts message
        exit 1
      end

    end
  end
end

module CfDeployer
  class ConfigLoader

    def self.component_json component, config
      json_file = File.join(config[:config_dir], "#{component}.json")
      raise ApplicationError.new("#{json_file} is missing") unless File.exists?(json_file)
      CfDeployer::Log.info "ERBing JSON for #{component}"
      ERB.new(File.read(json_file)).result(binding)
    rescue RuntimeError,TypeError,NoMethodError => e
      self.new.send :error_document, File.read(json_file)
      raise e
    end

    def load(options)
      config_text = File.read(options[:'config-file'])
      erbed_config = erb_with_environment_and_region(config_text, options[:environment], options[:region])
      yaml = symbolize_all_keys(load_yaml(erbed_config))
      @config = options.merge(yaml)
      @config[:components] ||= {}
      @config[:settings] ||= {}
      @config[:environments] ||= {}
      @config[:tags] ||= {}
      @config[:notify] ||= []
      get_targets
      copy_config_dir
      merge_hash(:settings)
      merge_hash(:inputs)
      merge_hash(:tags)
      merge_array(:notify)
      copy_region_app_env_component
      get_cf_template_keys('Parameters')
      get_cf_template_keys('Outputs')
      set_default_settings
      @config.delete(:settings)
      @config
    end

    private

    def load_yaml(text)
      YAML.load text
    rescue Psych::SyntaxError => e
      error_document text
      raise e
    rescue
      error_document text
      raise ApplicationError.new("The config file is not a valid yaml file")
    end

    def merge_array(section)
      root_value = to_array(@config[section])
      environment_name = @config[:environment] || ''
      environment = @config[:environments][environment_name.to_sym] || {}
      environment_value = to_array(environment[section])
      @config[:components].each do |component_name, component|
        component_value = to_array(component[section])
        component[section] = root_value + component_value + environment_value
        component[section].uniq!
      end
    end

    def error_document text
      puts "-" * 80
      puts text
      puts "-" * 80
    end

    def to_array(value)
      return value if value.is_a?(Array)
      return [] unless value
      [value]
    end

    def merge_hash(section)
      merge_component_options section
      merge_environment_options(@config[:environment], section)
      merge_environment_variables section
      @config[:cli_overrides] ||= {}
      merge_options(@config[:cli_overrides][section] || {}, section)
    end

    def get_targets
      @config[:component] ||= []
      @config[:targets] = @config[:component].length == 0 ? @config[:components].keys.map(&:to_s) : @config[:component]
    end

    def copy_region_app_env_component
      @config[:components].each do |component_name, component|
        component[:settings][:region]          = @config[:region]
        component[:inputs][:region]            = @config[:region]

        component[:settings][:application]          = @config[:application]
        component[:inputs][:application]            = @config[:application]

        component[:settings][:component]            = component_name.to_s
        component[:inputs][:component]              = component_name.to_s

        component[:settings][:environment]          = @config[:environment]
        component[:inputs][:environment]            = @config[:environment]
      end
    end

    def set_default_settings
      @config[:components].each do |component_name, component|
        if  component[:'deployment-strategy'] == 'cname-swap'
          component[:settings][:'elb-name-output'] ||= Defaults::ELBName
          component[:settings][:'dns-driver'] ||= Defaults::DNSDriver
        end
        component[:settings][:'raise-error-for-unused-inputs'] ||= Defaults::RaiseErrorForUnusedInputs
        component[:settings][:'auto-scaling-group-name-output'] ||= [Defaults::AutoScalingGroupName] if component[:'deployment-strategy'] == 'auto-scaling-group-swap'
        component[:settings][:'auto-scaling-group-name-output'] ||= [Defaults::AutoScalingGroupName] if component[:'defined_outputs'].keys.include?(Defaults::AutoScalingGroupName.to_sym)
        if component[:settings][:'keep-previous-stack'] == nil
          component[:settings][:'keep-previous-stack'] = Defaults::KeepPreviousStack
        end
      end
    end

    def get_cf_template_keys(name)
      @config[:components].keys.each do |component|
        parameters = cf_template(component)[name] || {}
        @config[:components][component]["defined_#{name.downcase}".to_sym] = symbolize_all_keys(parameters)
      end
    end

    def cf_template(component)
      config =  deep_dup(@config[:components][component])
      config[:inputs].each do |key, value|
        if value.is_a?(Hash)
          output_key = value[:'output-key']
          config[:inputs][key] = "#{value[:component]}::#{output_key}"
        end
      end

      json_content = self.class.component_json component.to_s, config
      CfDeployer::Log.info "Parsing JSON for #{component}"
      begin
        JSON.load json_content
      rescue JSON::ParserError => e
        puts json_content
        error_document e.message[0..300]
        raise "Couldn't parse JSON for component #{component}"
      end
    end

    def config_dir
      File.dirname(@config[:'config-file'])
    end

    def copy_config_dir
      @config[:components].each do |component_name, component|
        component ||= {}
        @config[:components][component_name] = component
        component[:config_dir] = config_dir
      end
    end

    def merge_component_options(section)
      common_options = @config[section] || {}
      @config[:components].keys.each do |component|
        @config[:components][component] ||= {}
        component_options = @config[:components][component].delete(section) || {}
        @config[:components][component][section] = common_options.merge(component_options)
      end
    end

    def merge_environment_options(environment_name, section)
      return unless environment_name
      environment = @config[:environments][environment_name.to_sym] || {}
      environment_options = environment[section] || {}
      merge_options(environment_options, section)
      environment_components = environment[:components] || {}
      merge_environment_component(environment_components, section)
    end

    def merge_options(options, section)
      @config[:components].keys.each do |component|
        component_options = @config[:components][component].delete(section) || {}
        @config[:components][component][section] = component_options.merge(options)
      end
    end

    def merge_environment_component(environment_components, section)
      environment_components.keys.each do |component|
        @config[:components][component] ||= {}
        component_options = @config[:components][component].delete(section) || {}
        @config[:components][component][section] = component_options.merge(environment_components[component][section] || {})
      end
    end

    def merge_environment_variables(section)
      @config[:components].keys.each do |component|
        merge_environment_variables_to_options( @config[:components][component][section], section)
      end
    end

    def merge_environment_variables_to_options(options, section)
      options.keys.each do |key|
        environment_variable = ENV["cfdeploy_#{section}_#{key.to_s}"]
        options[key] = environment_variable if environment_variable
      end
    end

    def symbolize_all_keys(hash)
      return hash unless hash.is_a?(Hash)
      hash.inject({}){|memo,(k,v)| memo.delete(k); memo[k.to_sym] = symbolize_all_keys(v); memo}
    end

    def erb_with_environment_and_region(contents, environment, region)
      ERB.new(contents).result(binding)
    end

    def deep_dup(hash)
      new_hash = {}
      hash.each do |key, value|
        value.is_a?(Hash) ? new_hash[key] = deep_dup(value) : new_hash[key] = value
      end
      new_hash
    end

  end
end

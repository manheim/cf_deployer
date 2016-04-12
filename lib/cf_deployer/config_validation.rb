module CfDeployer
  class ConfigValidation

    class ValidationError < ApplicationError
    end

    CommonInputs = [:application, :environment, :component, :region]
    EnvironmentOptions = [:settings, :inputs, :tags, :components]
    ComponentOptions = [:settings, :inputs, :tags, :'depends-on', :'deployment-strategy', :'before-destroy', :'after-create', :'after-swap', :'after-update', :'defined_outputs', :'defined_parameters', :config_dir, :capabilities, :notify]

    def validate config, validate_inputs = true
      @config = config
      @errors = []
      @warnings = []
      check_application_name
      check_components validate_inputs
      check_environments
      @warnings.each { |message| puts "WARNNING:#{message}" }
      raise ValidationError.new(@errors.join("\n")) if @errors.length > 0
    end

    private

    def check_asg_name_output(component)
      component[:settings][:'auto-scaling-group-name-output'] ||= []
      outputs = component[:settings][:'auto-scaling-group-name-output'].map { |name| name.to_sym }
      missing_output_keys = (outputs - component[:defined_outputs].keys)
       @errors << "'#{missing_output_keys.map(&:to_s)}' is not a CF stack output" unless missing_output_keys.empty?
    end

    def check_cname_swap_options(component)
      @errors << "dns-fqdn is required when using cname-swap deployment-strategy" unless component[:settings][:'dns-fqdn']
      @errors << "dns-zone is required when using cname-swap deployment-strategy" unless component[:settings][:'dns-zone']
      @errors << "'#{component[:settings][:'elb-name-output']}' is not a CF stack output, which is required by cname-swap deployment" unless component[:defined_outputs].keys.include?(component[:settings][:'elb-name-output'].to_sym)
    end

    def check_application_name
      @config[:application] = "" unless @config[:application]
      return @errors << "Application name is missing in config" unless @config[:application].length > 0
      @errors << "Application name cannot be longer than 100 and can only contain letters, numbers, '-' and '.'" unless @config[:application] =~ /^[a-zA-Z0-9\.-]{1,100}$/
    end

    def check_components validate_inputs
      @config[:components] ||= {}
      return @errors << "At least one component must be defined in config" unless @config[:components].length > 0
      deployable_components = @config[:targets] || []
      component_targets = @config[:components].select { |key, value| deployable_components.include?(key.to_s) }
      invalid_names = deployable_components - component_targets.keys.map(&:to_s)
      @errors <<  "Found invalid deployment components #{invalid_names}" if invalid_names.size > 0
      component_targets.each do |component_name, component|
        component[:settings] ||= {}
        component[:inputs] ||= {}
        component[:defined_outputs] ||= {}
        @errors << "Component name cannot be longer than 100 and can only contain letters, numbers, '-' and '.': #{component_name}" unless component_name =~ /^[A-Za-z0-9\.-]{1,100}$/
        check_parameters component_name, component if validate_inputs
        check_cname_swap_options(component) if component[:'deployment-strategy'] == 'cname-swap'
        check_asg_name_output(component)
        check_hooks(component)
        check_component_options(component_name, component)
      end
    end

    def check_component_options(name, component)
      component.keys.each do |option|
        @errors << "The option '#{option}' of the component '#{name}' is not valid" unless ComponentOptions.include?(option)
      end
    end

    def check_hooks(component)
      hook_names = [:'before-destroy', :'after-create', :'after-swap']
      hook_names.each do |hook_name|
        next unless component[hook_name] && component[hook_name].is_a?(Hash)
        @errors << "Invalid hook '#{hook_name}'" unless component[hook_name][:file] || component[hook_name][:code]
        check_hook_file(component, hook_name)
      end
    end

    def check_hook_file(component, hook_name)
      file_name = component[hook_name][:file]
      return unless file_name
      path = File.join(component[:config_dir], file_name)
      @errors << "File '#{path}' does not exist, which is required by hook '#{hook_name}'" unless File.exists?(path)
    end

    def check_environments
      @config[:environments] ||= {}
      @config[:environments].each do | name, environment |
        @errors << "Environment name cannot be longer than 12 and can only contain letters, numbers, '-' and '.': #{name}" unless name =~ /^[a-zA-Z0-9\.-]{1,12}$/
        check_environment_options(name, environment)
      end
    end

    def check_environment_options(name, environment)
      environment.keys.each do |option|
        @errors << "The option '#{option}' of the environment '#{name}' is not valid" unless EnvironmentOptions.include?(option)
        end
    end


    def check_parameters(component_name, component)
      component[:defined_parameters] ||= {}
      component[:defined_outputs] ||= {}
      component[:defined_parameters].each do | parameter_name, parameter |
        if component[:inputs].keys.include?(parameter_name) || parameter[:Default]
          check_output_reference(parameter_name, component_name)
        else
          @errors << "No input setting '#{parameter_name}' found for CF template parameter in component #{component_name}"
        end
      end
      check_un_used_inputs(component_name, component)
    end

    def check_un_used_inputs(component_name, component)
      component[:inputs].keys.each do |input|
        unless component[:defined_parameters].keys.include?(input) || CommonInputs.include?(input)
          message = "The input '#{input}' defined in the component '#{component_name}' is not used in the json template as a parameter"
          if component[:settings][:'raise-error-for-unused-inputs']
            @errors << message
          else
            @warnings << message
          end
        end
      end
    end


    def check_output_reference(setting_name, component_name)
      setting = @config[:components][component_name][:inputs][setting_name]
      return unless setting.is_a?(Hash)
      ref_component_name = setting[:component].to_sym
      ref_component = @config[:components][ref_component_name]
      if ref_component
        output_key = setting[:'output-key'].to_sym
        @errors << "No output '#{output_key}' found in CF template of component #{ref_component_name}, which is referenced by input setting '#{setting_name}' in component #{component_name}" unless ref_component[:defined_outputs].keys.include?(output_key)
      else
        @errors << "No component '#{ref_component_name}' found in CF template, which is referenced by input setting '#{setting_name}' in component #{component_name}"
      end
    end

  end
end

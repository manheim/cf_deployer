require 'diffy'

module CfDeployer
  class Component
    attr_reader :name, :dependencies, :children

    def initialize(application_name, environment_name, component_name, context)
      @application_name = application_name
      @environment_name = environment_name
      @name = component_name
      @context = context
      @dependencies = []
      @children = []
      Log.debug "initializing #{name}.."
      Log.debug @context
    end

    def exists?
       strategy.exists?
    end

    def kill_inactive
      strategy.kill_inactive
    end

    def deploy
      Log.debug "deploying #{name}..."
      @dependencies.each do |parent|
        parent.deploy unless(parent.exists?)
      end
      resolve_settings
      strategy.deploy
    end

    def json
      resolve_settings
      puts "#{name} json template:"
      puts ConfigLoader.component_json(name, @context)
    end

    def diff
      resolve_settings
      current_json = strategy.active_template
      if current_json
        puts "#{name} json template diff:"
        new_json = ConfigLoader.component_json(name, @context)
        Diffy::Diff.default_format = :color
        puts Diffy::Diff.new( current_json, new_json )
      else
        puts "No current json for component #{name}"
      end
    end

    def destroy
      raise ApplicationError.new("Unable to destroy #{name}, it is depended on by other components") if any_children_exist?
      strategy.destroy
    end

    def switch
      exists? ? strategy.switch : (raise ApplicationError.new("No stack exists for component: #{name}"))
    end


    def output_value(key)
      strategy.output_value(key)
    end

    def <=>(other)
      i_am_depednent = depends_on? other
      it_is_dependent = other.depends_on? self

      if i_am_depednent
        1
      elsif it_is_dependent
        -1
      else
        0
      end
    end

    def inspect
      "component: #{name}"
    end

    def depends_on?(component, source=self)
      raise ApplicationError.new("Cyclic dependency") if @dependencies.include?(source)
      @dependencies.include?(component) || @dependencies.any? { |d| d.depends_on?(component, source) }
    end

    def status get_resource_statuses
      strategy.status get_resource_statuses
    end

    def run_hook hook_name
      resolve_settings
      strategy.run_hook hook_name
    end

    private

    def resolve_settings
      inputs.each do |key, value|
        if(value.is_a?(Hash) && value.key?(:component))
          dependency = @dependencies.find { |d| d.name == value[:component] }
          raise "No component '#{value[:component]}' found when attempting to derive input '#{key}'" unless dependency
          output_key = value[:'output-key']
          inputs[key] = dependency.output_value(output_key)
        end
      end
    end

    def any_children_exist?
      children.any?(&:exists?)
    end

    def inputs
      @context[:inputs]
    end

    def strategy
      @strategy ||= DeploymentStrategy.create(@application_name, @environment_name, name, @context)
    end
  end
end

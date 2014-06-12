module CfDeployer
  class Application
    attr_reader :components

    def initialize(context = {})
     @context = context
     get_components
     add_component_dependencies
     @components.sort!
    end

    def get_components
      @components = []
      @context[:components].keys.each do | key |
        component = Component.new(@context[:application], @context[:environment], key.to_s, @context[:components][key])
        @components << component
      end
    end

    def add_component_dependencies
      @context[:components].keys.each do | key |
        component = @components.find { |c| c.name == key.to_s }
        dependencies = @context[:components][key][:'depends-on'] || []
        dependencies.each do | parent_name |
          parent = @components.find { |c| c.name == parent_name }
          if parent
            parent.children << component
            component.dependencies << parent
          end
        end
      end
    end

    def deploy
      Log.debug @context
      components = get_targets().sort
      components.each &:deploy
    end

    def json
      components = get_targets().sort
      components.each &:json
    end

    def status component_name, verbosity
      statuses = {}
      @components.select { |component|  component_name.nil? || component_name == component.name }.each do |component|
        statuses[component.name] = component.status(verbosity != 'stacks')
      end
      statuses
    end

    def run_hook component_name, hook_name
      @components.detect{ |component| component_name == component.name }.run_hook hook_name
    end

    def destroy
      components = get_targets.sort { |a, b| b <=> a }
      components.each &:destroy
    end

    def kill_inactive
      component = get_targets.first
      component.kill_inactive
    end

    def switch
      @context[:targets].each do | component_name |
        @components.find { |c| c.name == component_name }.switch
      end
    end

    private
    def get_targets
      targets = @components.select { |c| @context[:targets].include?(c.name) }
    end
  end
end

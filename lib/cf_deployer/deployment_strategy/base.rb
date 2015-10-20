module CfDeployer
  module DeploymentStrategy

    def self.create application_name, environment_name, component_name, context
      context[:'deployment-strategy'] ||= 'create-or-update'
      strategy_class_name = 'CfDeployer::DeploymentStrategy::' + context[:'deployment-strategy'].split('-').map(&:capitalize).join
      begin
        eval(strategy_class_name).new  application_name, component_name, environment_name, context
      rescue
        raise ApplicationError.new 'strategy_name: ' + strategy_class_name + ' not supported'
      end
    end

    class Base
      BLUE_GREEN_STRATEGY = true

      attr_reader :context, :component_name, :application_name, :environment_name
      def initialize(application_name, component_name, environment_name, context)
        @application_name = application_name
        @component_name = component_name
        @environment_name = environment_name
        @context = context
        @auto_scaling_group_drivers = {}
      end

      def blue_green_strategy?
        BLUE_GREEN_STRATEGY
      end

      def run_hook(hook_name)
        CfDeployer::Driver::DryRun.guard "Skipping hook #{hook_name}" do
          unless @params_and_outputs_resolved
            target_stack = ( active_stack || stack )
            unless target_stack.exists?
              CfDeployer::Log.info "Skipping hook call for #{hook_name} since stack #{target_stack.name} doesn't exist."
              return
            end
            get_parameters_outputs target_stack
          end
          hook = Hook.new hook_name, context[hook_name]
          hook.run context
        end
      end

      def active_template
        target_stack = ( active_stack || stack )
        (target_stack && target_stack.exists?) ? target_stack.template : nil
      end

      protected

      def stack_prefix
        "#{@application_name}-#{@environment_name}-#{@component_name}"
      end

      def delete_stack(stack)
        # Should this be stack.ready?  Outputs won't exist if the stack is still starting.
        unless stack.exists?
          CfDeployer::Log.info "Skipping deleting stack #{stack.name} since it doesn't exist."
          return
        end
        get_parameters_outputs stack
        run_hook :'before-destroy'
        stack.delete
      end

      def get_parameters_outputs(stack)
        CfDeployer::Driver::DryRun.guard "Skipping get_parameters_outputs" do
          @params_and_outputs_resolved = true
          context[:parameters] = stack.parameters
          context[:outputs] = stack.outputs
        end
      end

      def warm_up_inactive_stack
        group_ids(inactive_stack).each_with_index do |id, index|
          asg_driver(id).warm_up get_desired(id, index)
        end
      end

      def get_desired(id, index)
        group_id =  active_stack ? group_ids(active_stack)[index] : id
        asg_driver(group_id).describe[:desired]
      end

      def group_ids(stack)
        return [] unless asg_id_outputs
        asg_id_outputs.map { |id| stack.output id }
      end

      def asg_driver name
        @auto_scaling_group_drivers[name] ||= CfDeployer::Driver::AutoScalingGroup.new name
      end

      def asg_id_outputs
        @context[:settings][:'auto-scaling-group-name-output']
      end
    end
  end
end

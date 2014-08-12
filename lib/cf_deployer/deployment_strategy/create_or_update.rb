module CfDeployer
  module DeploymentStrategy
    class CreateOrUpdate < Base
      BLUE_GREEN_STRATEGY = false

      def exists?
        stack.exists?
      end

      def status get_resource_statuses = false
        my_status = {}
        my_status[stack.name] = {}
        my_status[stack.name][:status] = stack.status
        my_status[stack.name][:resources] = stack.resource_statuses if stack.exists? && get_resource_statuses
        my_status
      end


      def deploy
        hook_to_run = stack.exists? ? :'after-update' : :'after-create'
        stack.deploy
        warm_up_inactive_stack
        get_parameters_outputs(inactive_stack)
        run_hook(hook_to_run)
      end

      def output_value(key)
        exists? ? stack.output(key) : "The value will be referenced from the output #{key} of undeployed component #{component_name}"
      end

      def destroy
        delete_stack stack
      end

      def kill_inactive
        raise ApplicationError.new('There is no inactive version to kill for Create or Update Deployments.')
      end

      def switch
        raise ApplicationError.new('There is no inactive version to switch to for Create or Update Deployments.  Redeploy the version you want')
      end

      private

      def stack
        Stack.new(stack_prefix, @component_name, @context)
      end

      def inactive_stack
        stack
      end

      def active_stack
        nil
      end
    end
  end
end

module CfDeployer
  module DeploymentStrategy
    class BlueGreen < Base

      def exists?
        green_stack.exists? || blue_stack.exists?
      end

      def destroy
        delete_stack green_stack
        delete_stack blue_stack
      end


      def output_value(key)
        active_stack ? active_stack.output(key) : "The value will be referenced from the output #{key} of undeployed component #{component_name}"
      end

      def status get_resource_statuses = false
        my_status = {}
        [blue_stack, green_stack].each do |the_stack|
          my_status[the_stack.name] = {}
          my_status[the_stack.name][:active] = stack_active?(the_stack)
          my_status[the_stack.name][:status] = the_stack.status
          my_status[the_stack.name][:resources] = the_stack.resource_statuses if the_stack.exists? && get_resource_statuses
        end
        my_status
      end

      private

      def blue_stack
        name = "#{stack_prefix}-B"
        Stack.new(name, component_name, context)
      end

      def green_stack
        name = "#{stack_prefix}-G"
        Stack.new(name, component_name, context)
      end

      def both_stacks_exist?
        blue_stack.exists? && green_stack.exists?
      end

      def active_stack
        @active_stack = get_active_stack unless @active_stack_checked
        @active_stack
      end

      def inactive_stack
        @inactive_stack ||= get_inactive_stack
      end

      def get_inactive_stack
        return blue_stack unless active_stack
        stack_active?(green_stack) ? blue_stack : green_stack
      end

      def get_active_stack
        @active_stack_checked = true
        return green_stack if stack_active?(green_stack)
        return blue_stack if stack_active?(blue_stack)
        nil
      end


    end
  end
end

module CfDeployer
  module DeploymentStrategy
    class AutoScalingGroupSwap < BlueGreen


      def deploy
        check_blue_green_not_both_active 'Deployment'
        Log.info "Found active stack #{active_stack.name}" if active_stack
        delete_stack inactive_stack
        create_inactive_stack
        swap_group
        run_hook(:'after-swap')
        Log.info "Active stack has been set to #{inactive_stack.name}"
        delete_stack(active_stack) if active_stack && !keep_previous_stack
        Log.info "#{component_name} deployed successfully"
      end


      def kill_inactive
        check_blue_green_not_both_active 'Kill Inactive'
        raise ApplicationError.new('Only one color stack exists, cannot kill a non-existant version!') unless both_stacks_exist?
        delete_stack inactive_stack
      end

      def switch
        check_blue_green_not_both_active 'Switch'
        raise ApplicationError.new('Only one color stack exists, cannot switch to a non-existent version!') unless both_stacks_exist?
        warm_up_cooled = true
        swap_group warm_up_cooled
      end

      private


      def check_blue_green_not_both_active action
        begin
          active_stacks = get_active_asg(active_stack) + get_active_asg(inactive_stack)
          raise BothStacksActiveError.new("Found both auto-scaling-groups, #{active_stacks}, in green and blue stacks are active. #{action} aborted!") if both_stacks_active?
        rescue ApplicationError => ignored

        end
      end

      def swap_group is_switching_to_cooled = false
        is_switching_to_cooled ? warm_up_cooled_stack : warm_up_inactive_stack
        cool_down_active_stack if active_stack && (is_switching_to_cooled || keep_previous_stack)
      end

      def keep_previous_stack
        context[:settings][:'keep-previous-stack']
      end

      def create_inactive_stack
        inactive_stack.deploy
        get_parameters_outputs(inactive_stack)
        run_hook(:'after-create')
      end

      def both_stacks_active?
        active_stack && stack_active?(inactive_stack)
      end


      def warm_up_cooled_stack
        group_ids(active_stack).each_with_index do |id, index|
          min_max_desired = asg_driver(id).describe
          asg_driver(group_ids(inactive_stack)[index]).warm_up_cooled_group min_max_desired
        end
      end

      def cool_down_active_stack
        group_ids(active_stack).each do |id|
          asg_driver(id).cool_down
        end

      end

      def stack_active?(stack)
        return false unless stack.exists?
        get_active_asg(stack).any?
      end


      def get_active_asg stack
        return [] unless stack && stack.exists?
        group_ids(stack).select do |id|
          begin
            asg_driver = asg_driver(id)
            result = asg_driver.describe
            result[:min] > 0 && result[:max] > 0 && result[:desired] > 0
          rescue AWS::Core::Resource::NotFound => ignored

          end
        end
      end

      def asg_driver name
        @auto_scaling_group_drivers[name] ||= CfDeployer::Driver::AutoScalingGroup.new name
      end

      def asg_id_outputs
        @context[:settings][:'auto-scaling-group-name-output']
      end

      class BothStacksActiveError < ApplicationError
      end
    end
  end
end

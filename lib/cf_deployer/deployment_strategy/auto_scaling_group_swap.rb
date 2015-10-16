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
        swap_group true
      end

      private

      def check_blue_green_not_both_active action
        active_stacks = get_active_asgs(active_stack) + get_active_asgs(inactive_stack)
        raise BothStacksActiveError.new("Found both auto-scaling-groups, #{active_stacks}, in green and blue stacks are active. #{action} aborted!") if both_stacks_active?
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
        inactive_ids = template_asg_name_to_ids(inactive_stack)
        template_asg_name_to_ids(active_stack).each do |name, id|
          min_max_desired = asg_driver(id).describe
          asg_driver(inactive_ids[name]).warm_up_cooled_group min_max_desired
        end
      end

      def cool_down_active_stack
        active_stack.asg_ids.each do |id|
          asg_driver(id).cool_down
        end
      end

      def stack_active?(stack)
        stack.exists? && get_active_asgs(stack).any?
      end

      def get_active_asgs stack
        return [] unless stack && stack.exists?
        stack.asg_ids.select do |id|
          asg_driver = asg_driver(id)
          if asg_driver.exists?
            result = asg_driver.describe
            result[:min] > 0 && result[:max] > 0 && result[:desired] > 0
          end
        end
      end

      class BothStacksActiveError < ApplicationError
      end
    end
  end
end

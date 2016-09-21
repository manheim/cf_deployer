module CfDeployer
  module Driver
    class AutoScalingGroup
      extend Forwardable

      def_delegators :aws_group, :auto_scaling_instances, :ec2_instances, :load_balancers

      attr_reader :group_name, :group

      def initialize name, timeout = CfDeployer::Defaults::Timeout
        @group_name = name
        @timeout = timeout
      end

      def describe
        { desired: aws_group.desired_capacity, min: aws_group.min_size, max: aws_group.max_size }
      end

      def warm_up desired
        return if desired < aws_group.min_size
        desired = aws_group.max_size if desired > aws_group.max_size
        Log.info "warming up auto scaling group #{group_name} to #{desired}"

        CfDeployer::Driver::DryRun.guard "Skipping ASG warmup" do
          aws_group.set_desired_capacity desired
          wait_for_desired_capacity desired
        end
      end

      def warm_up_cooled_group options
        CfDeployer::Driver::DryRun.guard 'Skipping update of ASG min & max instance count' do
          aws_group.update :min_size => options[:min], :max_size => options[:max]
        end
        warm_up options[:desired]
      end

      def cool_down
        Log.info "Cooling down #{group_name}"
        CfDeployer::Driver::DryRun.guard "Skipping ASG cooldown" do
          aws_group.update :min_size => 0, :max_size => 0
          aws_group.set_desired_capacity 0
        end
      end

      def instance_statuses
        instance_info = {}
        ec2_instances.each do |instance|
          instance_info[instance.id] = CfDeployer::Driver::Instance.new(instance).status
        end
        instance_info
      end

      def wait_for_desired_capacity number
        Timeout::timeout(@timeout){
          until desired_capacity_reached?(number)
            sleep 15
          end
        }
      end

      def desired_capacity_reached? number
        healthy_instance_count == number
      end

      private

      def healthy_instance_count
        begin
          count = auto_scaling_instances.count do |instance|
            instance.health_status == 'HEALTHY' && (load_balancers.empty? || instance_in_service?( instance.ec2_instance ))
          end
          Log.info "Healthy instance count: #{count}"
          count
        rescue => e
          Log.info "Unable to determine healthy instance count due to error: #{e.message}"
          -1
        end
      end

      def instance_in_service? instance
        load_balancers.all? do |load_balancer|
          load_balancer.instances.health.any? do |health|
            health[:instance] == instance ? health[:state] == 'InService' : false
          end
        end
      end

      def aws_group
        @my_group ||= AWS::AutoScaling.new.groups[group_name]
      end
    end
  end
end

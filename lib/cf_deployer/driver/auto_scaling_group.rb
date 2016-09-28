module CfDeployer
  module Driver
    class AutoScalingGroup
      extend Forwardable

      def_delegators :aws_group, :auto_scaling_instances, :ec2_instances, :load_balancers, :desired_capacity

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
          wait_for_desired_capacity
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

      def wait_for_desired_capacity
        Timeout::timeout(@timeout){
          until desired_capacity_reached?
            sleep 15
          end
        }
      end

      def desired_capacity_reached?
        healthy_instance_count >= desired_capacity
      end

      def healthy_instance_ids
        instances = auto_scaling_instances.select do |instance|
          instance.health_status == 'HEALTHY'
        end
        instances.map(&:id)
      end

      def in_service_instance_ids
        elbs = load_balancers
        return [] if elbs.empty?

        ids = elbs.collect(&:instances)
                  .collect(&:health)
                  .to_a
                  .collect { |elb_healths|
                     elb_healths.select { |health| health[:state] == 'InService' }
                                .map { |health| health[:instance].id }
                  }

        ids.inject(:&)
      end

      def healthy_instance_count
        begin
          instances = healthy_instance_ids
          instances &= in_service_instance_ids unless load_balancers.empty?
          Log.info "Healthy instance count: #{instances.count}"
          instances.count
        rescue => e
          Log.info "Unable to determine healthy instance count due to error: #{e.message}"
          -1
        end
      end

      private

      def aws_group
        @my_group ||= AWS::AutoScaling.new.groups[group_name]
      end
    end
  end
end

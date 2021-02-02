module CfDeployer
  module Driver
    class CloudFormation

      def initialize stack_name
        @stack_name = stack_name
      end

      def stack_exists?
        !aws_stack.nil?
      end

      def create_stack template, opts
        CfDeployer::Driver::DryRun.guard "Skipping create_stack" do
          cloud_formation.create_stack(opts.merge(stack_name: @stack_name, template_body: template))
        end
      end

      def update_stack template, opts
        begin
          CfDeployer::Driver::DryRun.guard "Skipping update_stack" do
            cloud_formation.update_stack(opts.merge(stack_name: @stack_name, template_body: template))
          end

        rescue Aws::CloudFormation::Errors::ValidationError => e
          Log.info e.message
          return false
        rescue => e
          puts '*' * 80
          puts e
          raise
        end

        return !CfDeployer::Driver::DryRun.enabled?
      end

      def stack_status
        aws_stack.stack_status.downcase.to_sym
      end

      def outputs
        aws_stack.outputs.inject({}) do |memo, o|
          memo[o.output_key] = o.output_value
          memo
        end
      end

      def parameters
        aws_stack.parameters
      end

      def query_output key
        output = aws_stack.outputs.find { |o| o.output_key == key }
        output && output.output_value
      end

      def delete_stack
        if stack_exists?
          CfDeployer::Driver::DryRun.guard "Skipping create_stack" do
            cloud_formation.delete_stack(stack_name: @stack_name)
          end
        else
          Log.info "Stack #{@stack_name} does not exist!"
        end
      end

      def resource_statuses
        resources = {}
        cloud_formation.list_stack_resources(stack_name: @stack_name).stack_resource_summaries.each do |rs|
          resources[rs[:resource_type]] ||= {}
          resources[rs[:resource_type]][rs[:physical_resource_id]] = rs[:resource_status]
        end
        resources
      end

      def template
        aws_stack.template
      end

      private

      def cloud_formation
        Aws::CloudFormation::Client.new
      end

      def aws_stack
        cloud_formation.describe_stacks.stacks.find{|s| s.stack_name == @stack_name}
      end

    end
  end
end

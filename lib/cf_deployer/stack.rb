module CfDeployer
  class ResourceNotInReadyState < ApplicationError
  end

  class Stack
    SUCCESS_STATS = [:create_complete, :update_complete, :delete_complete]
    READY_STATS = SUCCESS_STATS - [:delete_complete]
    FAILED_STATS = [:create_failed, :update_failed, :delete_failed, :update_rollback_complete]


    def initialize(stack_name, component, context)
      @stack_name = stack_name
      @cf_driver = context[:cf_driver] || CfDeployer::Driver::CloudFormation.new(stack_name)
      @context = context
      @component = component
    end

    def deploy
      config_dir = @context[:config_dir]
      template = CfDeployer::ConfigLoader.erb_to_json(@component, @context)
      capabilities = @context[:capabilities] || []
      notify = @context[:notify] || []
      tags = @context[:tags] || {}
      params = @context[:inputs].select{|key, value| @context[:defined_parameters].keys.include?(key)}
        .map do |key, value|
          next nil unless @context[:defined_parameters].keys.include?(key)
          { parameter_key: key.to_s, parameter_value: value.to_s }
        end.compact

      CfDeployer::Driver::DryRun.guard "Skipping deploy" do
        if exists?
          override_policy_json = nil
          unless @context[:settings][:'override-stack-policy'].nil?
            override_policy_json = CfDeployer::ConfigLoader.erb_to_json(@context[:settings][:'override-stack-policy'], @context)
          end
          update_stack(template, params, capabilities, tags, override_policy_json)
        else
          create_policy_json = nil
          unless @context[:settings][:'create-stack-policy'].nil?
            create_policy_json = CfDeployer::ConfigLoader.erb_to_json(@context[:settings][:'create-stack-policy'], @context)
          end
          create_stack(template, params, capabilities, tags, notify, create_policy_json)
        end
      end
    end

    def outputs
      return {} unless ready?
      @cf_driver.outputs
    end

    def parameters
      return {} unless ready?
      @cf_driver.parameters
    end

    def output key
      find_output(key) || (raise ApplicationError.new("'#{key}' is empty from stack #{name} output"))
    end

    def find_output key
      begin
        @cf_driver.query_output(key)
      rescue Aws::CloudFormation::Errors::OperationStatusCheckFailedException => e
        raise ResourceNotInReadyState.new("Resource stack not in ready state yet, perhaps you should provision it first?")
      rescue => e
        puts '*' * 80
        puts e
        puts '*' * 80
        raise ResourceNotInReadyState.new("Resource stack not in ready state yet, perhaps you should provision it first?")
      end
    end

    def delete
      if exists?
        CfDeployer::Driver::DryRun.guard "Skipping delete" do
          Log.info "deleting stack #{@stack_name}"
          @cf_driver.delete_stack
          wait_for_stack_to_delete
        end
      end
    end

    def exists?
      @cf_driver.stack_exists?
    end

    def ready?
      READY_STATS.include? @cf_driver.stack_status
    end

    def status
      if exists?
        ready? ? :ready : :exists
      else
        :does_not_exist
      end
    end

    def resource_statuses
      resources = @cf_driver.resource_statuses.merge( { :asg_instances => {}, :instances => {} } )
      if resources['AWS::AutoScaling::AutoScalingGroup']
        resources['AWS::AutoScaling::AutoScalingGroup'].keys.each do |asg_name|
          resources[:asg_instances][asg_name] = CfDeployer::Driver::AutoScalingGroup.new(asg_name).instance_statuses
        end
      end
      if resources['AWS::EC2::Instance']
        resources['AWS::EC2::Instance'].keys.each do |instance_id|
          resources[:instances][instance_id] = CfDeployer::Driver::Instance.new(instance_id).status
        end
      end
      resources
    end

    def name
      @stack_name
    end

    def template
      @cf_driver.template
    end

    private

    def update_stack(template, params, capabilities, tags, override_policy_json)
      Log.info "Updating stack #{@stack_name}..."
      args = {
        :capabilities => capabilities,
        :parameters => params
      }
      unless override_policy_json.nil?
        args[:stack_policy_during_update_body] = override_policy_json
      end
      stack_updated = @cf_driver.update_stack(template, args)
      wait_for_stack_op_terminate if stack_updated
    end

    def create_stack(template, params, capabilities, tags, notify, create_policy_json)
      Log.info "Creating stack #{@stack_name}..."
      args = {
        :disable_rollback => true,
        :capabilities => capabilities,
        :notification_arns => notify,
        :tags => reformat_tags(tags),
        :parameters => params
      }
      unless create_policy_json.nil?
        args[:stack_policy_body] = create_policy_json
      end
      @cf_driver.create_stack(template, args)
      wait_for_stack_op_terminate
    end

    def stack_status
      @cf_driver.stack_status || :does_not_exist
    end

    def wait_for_stack_op_terminate
      stats = stack_status
      while !SUCCESS_STATS.include?(stats)
        sleep 15
        stats = stack_status
        raise ApplicationError.new("Resource stack update failed!") if FAILED_STATS.include? stats
        Log.info "current status: #{stack_status}"
      end
    end

    def wait_for_stack_to_delete
      Timeout::timeout(900){
        while exists?
          begin
            Log.info "current status: #{stack_status}"
            sleep 15
          rescue Aws::CloudFormation::Errors::StackSetNotFoundException => e
            break # This is what we wanted anyway
          rescue => e
            puts '*' * 80
            puts e
            raise e
          end
        end
      }
    end

    def reformat_tags tags_hash
      tags_hash.keys.map { |key| { :key => key.to_s, :value => tags_hash[key].to_s } }
    end
  end
end

require 'spec_helper'

describe CfDeployer::Stack do
  before do
    @cf_driver = double CfDeployer::Driver::CloudFormation
    @stack = CfDeployer::Stack.new('test', 'web', {:cf_driver => @cf_driver})
    @config = {
      :inputs => { :foo => :bar, :goo => :hoo },
      :tags => { :app => 'app1', :env => 'dev'},
      :defined_parameters => { :foo => 'bar' },
      :notify => ['topic1_arn', 'topic2_arn'],
      :cf_driver => @cf_driver,
      :settings => {
        'create-stack-policy' => nil,
        'override-stack-policy' => nil
      }
    }
  end

  context '#deploy' do
    it 'creates a stack, when it doesnt exist' do
      template = { :resources => {}}
      allow(CfDeployer::ConfigLoader).to receive(:erb_to_json).with('web', @config).and_return(template)
      allow(@cf_driver).to receive(:stack_exists?) { false }
      allow(@cf_driver).to receive(:stack_status) { :create_complete }
      expected_opt = {
        :disable_rollback => true,
        :capabilities => [],
        :notify => ['topic1_arn', 'topic2_arn'],
        :tags => [{'Key' => 'app', 'Value' => 'app1'},
                  {'Key' => 'env', 'Value' => 'dev'}],
        :parameters => {:foo => 'bar'}
      }
      expect(@cf_driver).to receive(:create_stack).with(template, expected_opt)
      stack = CfDeployer::Stack.new('test','web', @config)
      stack.deploy
    end

    it 'creates a stack using a policy when defined' do
      template = { :resources => {}}
      create_policy = { :Statement => [] }
      @config[:settings][:'create-stack-policy'] = 'create-policy'
      allow(CfDeployer::ConfigLoader).to receive(:erb_to_json).with('web', @config).and_return(template)
      allow(CfDeployer::ConfigLoader).to receive(:erb_to_json).with('create-policy', @config).and_return(create_policy)
      allow(@cf_driver).to receive(:stack_exists?) { false }
      allow(@cf_driver).to receive(:stack_status) { :create_complete }
      expected_opt = {
        :disable_rollback => true,
        :capabilities => [],
        :notify => ['topic1_arn', 'topic2_arn'],
        :tags => [{'Key' => 'app', 'Value' => 'app1'},
                  {'Key' => 'env', 'Value' => 'dev'}],
        :parameters => {:foo => 'bar'},
        :stack_policy_body => create_policy
      }
      expect(@cf_driver).to receive(:create_stack).with(template, expected_opt)
      stack = CfDeployer::Stack.new('test','web', @config)
      stack.deploy
    end

    it 'updates a stack, when it exists' do
      template = { :resources => {}}
      allow(CfDeployer::ConfigLoader).to receive(:erb_to_json).with('web', @config).and_return(template)
      allow(@cf_driver).to receive(:stack_exists?) { true }
      allow(@cf_driver).to receive(:stack_status) { :create_complete }
      expected_opt = {
        :capabilities => [],
        :parameters => {:foo => 'bar'}
      }
      expect(@cf_driver).to receive(:update_stack).with(template, expected_opt)
      stack = CfDeployer::Stack.new('test','web', @config)
      stack.deploy
    end

    it 'waits for result when stack is updated' do
      template = { :resources => {}}
      allow(CfDeployer::ConfigLoader).to receive(:erb_to_json).with('web', @config).and_return(template)
      allow(@cf_driver).to receive(:stack_exists?) { true }
      allow(@cf_driver).to receive(:stack_status) { :create_complete }
      expected_opt = {
        :capabilities => [],
        :parameters => {:foo => 'bar'}
      }
      expect(@cf_driver).to receive(:update_stack).with(template, expected_opt).and_return(true)
      stack = CfDeployer::Stack.new('test','web', @config)
      expect(stack).to receive(:wait_for_stack_op_terminate)
      stack.deploy
    end

    it 'does not wait for result when stack is not updated' do
      template = { :resources => {}}
      allow(CfDeployer::ConfigLoader).to receive(:erb_to_json).with('web', @config).and_return(template)
      allow(@cf_driver).to receive(:stack_exists?) { true }
      allow(@cf_driver).to receive(:stack_status) { :create_complete }
      expected_opt = {
        :capabilities => [],
        :parameters => {:foo => 'bar'}
      }
      expect(@cf_driver).to receive(:update_stack).with(template, expected_opt).and_return(false)
      stack = CfDeployer::Stack.new('test','web', @config)
      expect(stack).to_not receive(:wait_for_stack_op_terminate)
      stack.deploy
    end

    it 'does not fail if deployment caused no updates, and stack was already in a rollback state' do
      template = { :resources => {}}
      allow(CfDeployer::ConfigLoader).to receive(:erb_to_json).with('web', @config).and_return(template)
      allow(@cf_driver).to receive(:stack_exists?) { true }
      allow(@cf_driver).to receive(:stack_status) { :update_rollback_complete }
      expected_opt = {
        :capabilities => [],
        :parameters => {:foo => 'bar'}
      }
      expect(@cf_driver).to receive(:update_stack).with(template, expected_opt).and_return(false)
      stack = CfDeployer::Stack.new('test','web', @config)
      stack.deploy
    end

    it 'updates a stack using the override policy, when defined' do
      template = { :resources => {}}
      override_policy = { :Statement => [] }
      @config[:settings][:'override-stack-policy'] = 'override-policy'
      allow(CfDeployer::ConfigLoader).to receive(:erb_to_json).with('web', @config).and_return(template)
      allow(CfDeployer::ConfigLoader).to receive(:erb_to_json).with('override-policy', @config).and_return(override_policy)
      allow(@cf_driver).to receive(:stack_exists?) { true }
      allow(@cf_driver).to receive(:stack_status) { :create_complete }
      expected_opt = {
        :capabilities => [],
        :parameters => {:foo => 'bar'},
        :stack_policy_during_update_body => override_policy
      }
      expect(@cf_driver).to receive(:update_stack).with(template, expected_opt)
      stack = CfDeployer::Stack.new('test','web', @config)
      stack.deploy
    end

  end

  context '#parameters' do
    it "should get parameters"  do
      parameters = double('parameters')
      allow(@cf_driver).to receive(:parameters){ parameters }
      allow(@cf_driver).to receive(:stack_status) { :create_complete }
      expect(@stack.parameters).to eq(parameters)
    end

    it "should get empty hash if stack is not ready"  do
      allow(@cf_driver).to receive(:stack_status) { :create_inprogress }
      expect(@stack.parameters).to eq({})
    end
  end

  context '#outputs' do
    it "should get outputs"  do
      outputs = double('outputs')
      allow(@cf_driver).to receive(:outputs){ outputs }
      allow(@cf_driver).to receive(:stack_status) { :create_complete }
      expect(@stack.outputs).to eq(outputs)
    end

    it "should get empty hash if stack is not ready"  do
      outputs = double('outputs')
      allow(@cf_driver).to receive(:stack_status) { :create_inprogress }
      expect(@stack.outputs).to eq({})
    end
  end

  context '#output' do
    it 'should get output value' do
      expect(@cf_driver).to receive(:query_output).with('mykey'){ 'myvalue'}
      @stack.output('mykey').should eq('myvalue')
    end

    it 'should get error if output is empty' do
      expect(@cf_driver).to receive(:query_output).with('mykey'){ nil }
      expect{@stack.output('mykey')}.to raise_error("'mykey' is empty from stack test output")
    end
  end

  context '#find_output' do
    it 'should get output value' do
      expect(@cf_driver).to receive(:query_output).with('mykey'){ 'myvalue'}
      @stack.find_output('mykey').should eq('myvalue')
    end

    it 'should return nil for non-existent value' do
      expect(@cf_driver).to receive(:query_output).with('mykey'){ nil }
      @stack.find_output('mykey').should be(nil)
    end
  end

  context "#ready?" do
    CfDeployer::Stack::READY_STATS.each do |status|
      it "should be ready when in #{status} status" do
        allow(@cf_driver).to receive(:stack_status) { status }
        expect(@stack).to be_ready
      end
    end

    it "should not be ready when not in a ready status" do
      allow(@cf_driver).to receive(:stack_status) { :my_fake_status }
      expect(@stack).not_to be_ready
    end
  end

  describe '#delete' do
    it 'should delete the stack' do
      allow(@stack).to receive(:exists?).and_return(true, false)
      expect(@cf_driver).to receive(:delete_stack)
      @stack.delete
    end

    it 'should not delete the stack if it does not exist' do
      allow(@stack).to receive(:exists?) { false }
      expect(@cf_driver).not_to receive(:delete_stack)
      @stack.delete
    end

    it 'should be fine to get not exist error after deletion' do
      allow(@stack).to receive(:exists?).and_return(true, true)
      allow(@stack).to receive(:stack_status).and_raise(Aws::CloudFormation::Errors::StackSetNotFoundException.new(nil, 'the stack does not exist'))
      expect(@cf_driver).to receive(:delete_stack)
      expect {@stack.delete}.not_to raise_error
    end

    it 'should raise an error if a validation error is thrown not about stack does not exist' do
      allow(@stack).to receive(:exists?).and_return(true, true)
      allow(@stack).to receive(:stack_status).and_raise(Aws::CloudFormation::Errors::InvalidOperationException.new(nil, 'I am an error'))
      expect(@cf_driver).to receive(:delete_stack)
      expect {@stack.delete}.to raise_error
    end
  end

  describe '#status' do
    it "should be :ready if the stack is ready" do
      allow(@stack).to receive(:exists?) { true }
      allow(@stack).to receive(:ready?)  { true }
      expect(@stack.status).to eq(:ready)
    end

    it 'should be :exists if it exists but is not ready' do
      allow(@stack).to receive(:exists?) { true }
      allow(@stack).to receive(:ready?) { false }
      expect(@stack.status).to eq(:exists)
    end

    it 'should be :does_not_exist if it does not exist' do
      allow(@stack).to receive(:exists?) { false }
      expect(@stack.status).to eq(:does_not_exist)
    end
  end

  describe '#resource_statuses' do
    it 'should get resource_statuses from the CF driver' do
      rs =  { :something => :some_status }
      expect(@cf_driver).to receive(:resource_statuses) { rs }
      expect(@stack.resource_statuses[:something]).to eq(:some_status)
    end

    it 'should add instance status info for instances in ASGs' do
      asg = double CfDeployer::Driver::AutoScalingGroup
      rs = { 'AWS::AutoScaling::AutoScalingGroup' => { 'ASG123' => :some_status } }
      expect(@cf_driver).to receive(:resource_statuses) { rs }
      expect(asg).to receive(:instance_statuses) { { 'i-abcd1234' => { :status => :some_status } } }
      expect(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('ASG123') { asg }
      expect(@stack.resource_statuses[:asg_instances]['ASG123']['i-abcd1234'][:status]).to eq(:some_status)
    end

    it 'should add instance status info for instances NOT in ASGs' do
      instance = double CfDeployer::Driver::Instance
      rs = { 'AWS::EC2::Instance' => { 'i-abcd1234' => :some_status } }
      expect(@cf_driver).to receive(:resource_statuses) { rs }
      expect(CfDeployer::Driver::Instance).to receive(:new).with('i-abcd1234') { instance }
      expect(instance).to receive(:status) { { :status => :some_status } }
      expect(@stack.resource_statuses[:instances]['i-abcd1234'][:status]).to eq(:some_status)
    end
  end

end

require 'spec_helper'

describe 'Base Deployment Strategy' do
  let(:app) { 'myapp' }
  let(:env) { 'dev' }
  let(:component) { 'worker' }

  let(:context) {
        {
          :'deployment-strategy' => 'base',
          :settings => {
            :'auto-scaling-group-name-output' => ['AutoScalingGroupID']
          }
        }
  }

  let(:blue_stack)   { Fakes::Stack.new(name: 'BLUE',  outputs: {'web-elb-name' => 'BLUE-elb'},  status: :ready) }
  let(:green_stack)  { Fakes::Stack.new(name: 'GREEN', outputs: {'web-elb-name' => 'GREEN-elb'}, status: :does_not_exist, exists?: false) }
  let(:white_stack)  { Fakes::Stack.new(name: 'WHITE', outputs: {'web-elb-name' => 'WHITE-elb'}, status: :exists) }

  before do
    @strategy = CfDeployer::DeploymentStrategy::Base.new app, env, component, context
    allow(@strategy).to receive(:blue_stack)  { blue_stack  }
    allow(@strategy).to receive(:green_stack) { green_stack }
    allow(@strategy).to receive(:stack_active?).with(blue_stack) { true }
    allow(@strategy).to receive(:stack_active?).with(green_stack) { false }
  end


  describe '.create' do
    it "should pass back a new strategy object" do
      new_context = context.merge( { :'deployment-strategy' => 'cname-swap' } )
      expect(CfDeployer::DeploymentStrategy::CnameSwap).to receive(:new)
      my_strategy = CfDeployer::DeploymentStrategy.create app, env, component, new_context
    end

    it "should raise if the specified strategy doesn't exist" do
      new_context = context.merge( { :'deployment-strategy' => 'invade-russia' } )
      expect {
        CfDeployer::DeploymentStrategy.create app, env, component, new_context
      }.to raise_error(CfDeployer::ApplicationError)
    end
  end

  describe '#active_template' do
    before :each do
      @context = {
        application: 'myApp',
        environment: 'uat',
        components:
        { base: {:'deployment-strategy' => 'create-or-update'},
          db:  {:'deployment-strategy' => 'auto-scaling-group-swap'},
          web: { :'deployment-strategy' => 'cname-swap' }
          }
        }
    end

    it "should return nil if there is no active stack" do
      the_stack = double()
      expect(the_stack).to receive(:exists?).and_return(false)
      expect(the_stack).not_to receive(:template)

      strategy = CfDeployer::DeploymentStrategy.create('myApp', 'uat', 'web', @context[:components][:web])
      expect(strategy).to receive(:active_stack).and_return(the_stack)

      expect( strategy.active_template ).to eq(nil)
    end

    it "should return the JSON template of the active stack, if there is one" do
      the_template = double

      the_stack = double
      expect(the_stack).to receive(:exists?).and_return(true)
      expect(the_stack).to receive(:template).and_return(the_template)

      strategy = CfDeployer::DeploymentStrategy.create('myApp', 'uat', 'web', @context[:components][:web])
      expect(strategy).to receive(:active_stack).and_return(the_stack)

      expect( strategy.active_template ).to eq(the_template)
    end
  end

  describe '#run_hook' do
    before :each do
      @context = {
        application: 'myApp',
        environment: 'uat',
        components:
        { base: {:'deployment-strategy' => 'create-or-update'},
          db:  {:'deployment-strategy' => 'auto-scaling-group-swap'},
          web: { :'deployment-strategy' => 'cname-swap' }
          }
        }
    end

    it "should run the specified hook" do
      hook = double()
      expect(CfDeployer::Hook).to receive(:new).and_return(hook)
      expect(hook).to receive(:run)

      strategy = CfDeployer::DeploymentStrategy.create('myApp', 'uat', 'web', @context[:components][:web])
      strategy.instance_variable_set('@params_and_outputs_resolved', true)
      strategy.run_hook(:some_hook)
    end

    it "should not try to resolve parameters and outputs they're already initialized" do
      strategy = CfDeployer::DeploymentStrategy.create('myApp', 'uat', 'web', @context[:components][:web])
      strategy.instance_variable_set('@params_and_outputs_resolved', true)
      expect(strategy).not_to receive(:get_parameters_outputs)
      strategy.run_hook(:some_hook)
    end

    it "should not try to resolve parameters and outputs if there's no running stack" do
      the_stack = double()
      expect(the_stack).to receive(:exists?).and_return(false)
      expect(the_stack).to receive(:name).and_return("thestack")

      strategy = CfDeployer::DeploymentStrategy.create('myApp', 'uat', 'web', @context[:components][:web])
      expect(strategy).to receive(:active_stack).and_return(the_stack)
      expect(strategy).not_to receive(:get_parameters_outputs)
      strategy.run_hook(:some_hook)
    end

    it "should not try to run a hook if there's no running stack" do
      expect(CfDeployer::Hook).not_to receive(:new)

      the_stack = double()
      expect(the_stack).to receive(:exists?).and_return(false)
      expect(the_stack).to receive(:name).and_return("thestack")

      strategy = CfDeployer::DeploymentStrategy.create('myApp', 'uat', 'web', @context[:components][:web])
      expect(strategy).to receive(:active_stack).and_return(the_stack)
      strategy.run_hook(:some_hook)
    end
  end

  context '#warm_up_stack' do
    let(:context) {
      {
          :'deployment-strategy' => 'base',
          :settings => {
              :'auto-scaling-group-name-output' => ['ASG1', 'ASG2']
          }
      }
    }
    let(:blue_stack) { double('blue_stack') }
    let(:green_stack) { double('green_stack') }
    let(:blue_asg_driver_1) { double('blue_asg_driver_1') }
    let(:blue_asg_driver_2) { double('blue_asg_driver_2') }
    let(:green_asg_driver_1) { double('green_asg_driver_1') }
    let(:green_asg_driver_2) { double('green_asg_driver_2') }

    before :each do
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blue_asg_driver_1') { blue_asg_driver_1 }
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blue_asg_driver_2') { blue_asg_driver_2 }
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('green_asg_driver_1') { green_asg_driver_1 }
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('green_asg_driver_2') { green_asg_driver_2 }

      allow(green_stack).to receive(:find_output).with('ASG1') { 'green_asg_driver_1' }
      allow(green_stack).to receive(:find_output).with('ASG2') { 'green_asg_driver_2' }
    end

    it 'should warm up ASG with previous stack ASG values when present' do
      allow(blue_stack).to receive(:resource_statuses) { { 'blueASG1' => nil, 'blueASG2' => nil } }
      allow(blue_stack).to receive(:find_output).with('ASG1') { 'blue_asg_driver_1' }
      allow(blue_stack).to receive(:find_output).with('ASG2') { 'blue_asg_driver_2' }
      allow(blue_asg_driver_1).to receive(:describe) { {min: 1, desired: 2, max: 3} }
      allow(blue_asg_driver_2).to receive(:describe) { {min: 2, desired: 3, max: 4} }
      strategy = CfDeployer::DeploymentStrategy.create('myApp', 'uat', 'web', context)

      expect(green_asg_driver_1).to receive(:warm_up).with(2)
      expect(green_asg_driver_2).to receive(:warm_up).with(3)
      strategy.send(:warm_up_stack, green_stack, blue_stack)
    end

    it 'should warm up ASG with own values when previous stack does not contain ASG' do
      allow(blue_stack).to receive(:find_output).with(anything) { nil }
      allow(green_asg_driver_1).to receive(:describe) { {min: 3, desired: 4, max: 5} }
      allow(green_asg_driver_2).to receive(:describe) { {min: 4, desired: 5, max: 6} }
      strategy = CfDeployer::DeploymentStrategy.create('myApp', 'uat', 'web', context)

      expect(green_asg_driver_1).to receive(:warm_up).with(4)
      expect(green_asg_driver_2).to receive(:warm_up).with(5)
      strategy.send(:warm_up_stack, green_stack, blue_stack)
    end
  end

  context '#template_asg_name_to_ids' do
    let(:context) {
      {
          :'deployment-strategy' => 'base',
          :settings => {
              :'auto-scaling-group-name-output' => ['ASG1', 'ASG2']
          }
      }
    }

    it 'should map names in templates to stack outputs' do
      allow(blue_stack).to receive(:find_output).with('ASG1') { 'blue_asg_driver_1' }
      allow(blue_stack).to receive(:find_output).with('ASG2') { 'blue_asg_driver_2' }
      expected = {
          'ASG1' => 'blue_asg_driver_1',
          'ASG2' => 'blue_asg_driver_2',
      }

      strategy = CfDeployer::DeploymentStrategy.create('myApp', 'uat', 'web', context)
      expect(strategy.send(:template_asg_name_to_ids, blue_stack)).to eq(expected)
    end
  end
end

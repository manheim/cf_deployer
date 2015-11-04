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
      # strategy.should_not_receive(:get_parameters_outputs)

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
end

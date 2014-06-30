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
end

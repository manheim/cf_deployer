require 'spec_helper'

describe 'Auto Scaling Group Swap Deployment Strategy' do
  let(:app) { 'myapp' }
  let(:env) { 'dev' }
  let(:component) { 'worker' }

  let(:context) {
        {
          :'deployment-strategy' => 'auto-scaling-group-swap',
          :settings => {
            :'auto-scaling-group-name-output' => ['AutoScalingGroupID']
          }
        }
  }

  let(:blue_asg_driver) { double('blue_asg_driver') }
  let(:green_asg_driver) { double('green_asg_driver') }

  let(:blue_stack)  { Fakes::Stack.new(name: 'BLUE', outputs: {'web-elb-name' => 'BLUE-elb'}, parameters: { name: 'blue'}) }
  let(:green_stack)  { Fakes::Stack.new(name: 'GREEN', outputs: {'web-elb-name' => 'GREEN-elb'}, parameters: { name: 'green'}) }

  before :each do
    allow(blue_stack).to receive(:output).with('AutoScalingGroupID'){'blueASG'}
    allow(green_stack).to receive(:output).with('AutoScalingGroupID'){'greenASG'}
    allow(blue_stack).to receive(:find_output).with('AutoScalingGroupID'){'blueASG'}
    allow(green_stack).to receive(:find_output).with('AutoScalingGroupID'){'greenASG'}
    allow(blue_stack).to receive(:asg_ids) { ['blueASG'] }
    allow(green_stack).to receive(:asg_ids) { ['greenASG'] }
    allow(blue_asg_driver).to receive(:'exists?').and_return(true)
    allow(green_asg_driver).to receive(:'exists?').and_return(true)
    allow(CfDeployer::Stack).to receive(:new).with('myapp-dev-worker-B', 'worker', context) { blue_stack }
    allow(CfDeployer::Stack).to receive(:new).with('myapp-dev-worker-G', 'worker', context) { green_stack }
  end

  context 'component exists?' do
    it 'no if no G and B stacks exist' do
      blue_stack.die!
      green_stack.die!
      CfDeployer::DeploymentStrategy.create(app, env, component, context).exists?.should be_false
    end

    it 'yes if B stacks exist' do
      blue_stack.live!
      green_stack.die!
      CfDeployer::DeploymentStrategy.create(app, env, component, context).exists?.should be_true
    end
    it 'yes if G  stacks exist' do
      blue_stack.die!
      green_stack.live!
      CfDeployer::DeploymentStrategy.create(app, env, component, context).exists?.should be_true
    end

  end

  context 'has no active group' do
    it 'should deploy blue stack and warm up if green stack does not exist' do
      blue_stack.live!
      green_stack.die!
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
      allow(blue_asg_driver).to receive(:describe).and_return({desired: 0, min: 0, max: 0}, {desired: 1, min: 1, max: 1})
      expect(blue_asg_driver).to receive(:warm_up)
      expect(blue_stack).to receive(:delete)
      expect(blue_stack).to receive(:deploy)
      CfDeployer::DeploymentStrategy.create(app, env, component, context).deploy
    end

     it 'should deploy blue stack if green stack is not active' do
      blue_stack.die!
      green_stack.live!
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('greenASG') { green_asg_driver }
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
      allow(green_asg_driver).to receive(:describe) { {desired: 0, min: 0, max: 0} }
      allow(blue_asg_driver).to receive(:describe) { {desired: 1, min: 1, max: 2} }
      expect(blue_stack).to receive(:deploy)
      allow(blue_asg_driver).to receive(:warm_up)
      CfDeployer::DeploymentStrategy.create(app, env, component, context).deploy
    end
  end

  context 'hooks' do
    let(:before_destroy_hook) { double('before_destroy_hook') }
    let(:after_create_hook) { double('after_create_hook') }
    let(:after_swap_hook) { double('after_swap_hook') }

    before :each do
      allow(CfDeployer::Hook).to receive(:new).with(:'before-destroy', 'before-destroy'){ before_destroy_hook }
      allow(CfDeployer::Hook).to receive(:new).with(:'after-create', 'after-create'){ after_create_hook }
      allow(CfDeployer::Hook).to receive(:new).with(:'after-swap', 'after-swap'){ after_swap_hook }
      context[:'before-destroy'] = 'before-destroy'
      context[:'after-create'] = 'after-create'
      context[:'after-swap'] = 'after-swap'
    end

    it 'should call hooks when deploying' do
      blue_stack.live!
      green_stack.live!
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('greenASG') { green_asg_driver }
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
      allow(blue_asg_driver).to receive(:describe) {{desired: 0, min: 0, max: 0}}
      allow(green_asg_driver).to receive(:describe) {{desired: 2, min: 1, max: 5}}
      allow(blue_stack).to receive(:delete)
      allow(blue_stack).to receive(:deploy)
      allow(blue_asg_driver).to receive(:warm_up).with(2)
      allow(green_asg_driver).to receive(:cool_down)
      expect(before_destroy_hook).to receive(:run).with(context).twice
      expect(after_create_hook).to receive(:run).with(context)
      expect(after_swap_hook).to receive(:run).with(context)
      CfDeployer::DeploymentStrategy.create(app, env, component, context).deploy
      expect(context[:parameters]).to eq({ name: 'green'})
      expect(context[:outputs]).to eq({ "web-elb-name" => 'GREEN-elb'})
    end

    it 'should call hooks when destroying' do
      @log = ''
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('greenASG') { green_asg_driver }
      allow(blue_asg_driver).to receive(:describe) {{desired: 1, min: 1, max: 2}}
      allow(green_asg_driver).to receive(:describe) {{desired: 0, min: 0, max: 0}}
      green_stack.live!
      blue_stack.live!
      allow(green_stack).to receive(:delete)
      allow(blue_stack).to receive(:delete)
      allow(before_destroy_hook).to receive(:run) do |arg|
        @log += "#{arg[:parameters][:name]} deleted."
      end
      CfDeployer::DeploymentStrategy.create(app, env, component, context).destroy
      @log.should eq('green deleted.blue deleted.')
    end
  end

  context 'has active group' do
    it 'should deploy blue stack if green stack is active' do
      blue_stack.live!
      green_stack.live!
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('greenASG') { green_asg_driver }
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
      allow(blue_asg_driver).to receive(:describe) {{desired: 0, min: 0, max: 0}}
      allow(green_asg_driver).to receive(:describe) {{desired: 2, min: 1, max: 5}}
      expect(blue_stack).to receive(:delete)
      expect(blue_stack).to receive(:deploy)
      expect(blue_asg_driver).to receive(:warm_up).with(2)
      CfDeployer::DeploymentStrategy.create(app, env, component, context).deploy
    end

     it 'should deploy green stack if blue stack is active' do
      blue_stack.live!
      green_stack.live!
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('greenASG') { green_asg_driver }
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
      allow(green_asg_driver).to receive(:describe) {{desired: 0, min: 0, max: 0}}
      allow(blue_asg_driver).to receive(:describe) {{desired: 3, min: 1, max: 5}}
      expect(green_stack).to receive(:delete)
      expect(green_stack).to receive(:deploy)
      expect(green_asg_driver).to receive(:warm_up)
      CfDeployer::DeploymentStrategy.create(app, env, component, context).deploy
    end

    it 'should delete blue stack after deploying green' do
      blue_stack.live!
      green_stack.live!
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('greenASG') { green_asg_driver }
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
      allow(green_asg_driver).to receive(:describe) {{desired: 0, min: 0, max: 0}}
      allow(blue_asg_driver).to receive(:describe) {{desired: 3, min: 1, max: 5}}
      allow(green_asg_driver).to receive(:warm_up)
      expect(blue_asg_driver).not_to receive(:cool_down)
      CfDeployer::DeploymentStrategy.create(app, env, component, context).deploy

      expect(blue_stack).to be_deleted
    end

    it 'should not delete blue stack after deploying green if keep-previous-stack is specified' do
      blue_stack.live!
      green_stack.live!
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('greenASG') { green_asg_driver }
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
      allow(green_asg_driver).to receive(:describe) {{desired: 0, min: 0, max: 0}}
      allow(blue_asg_driver).to receive(:describe) {{desired: 3, min: 1, max: 5}}
      allow(green_asg_driver).to receive(:warm_up)
      expect(blue_asg_driver).to receive(:cool_down)
      context[:settings][:'keep-previous-stack'] = true
      CfDeployer::DeploymentStrategy.create(app, env, component, context).deploy

      expect(blue_stack).not_to be_deleted
    end


    it 'should get error if both blue and green stacks are active' do
      blue_stack.live!
      green_stack.live!
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('greenASG') { green_asg_driver }
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
      allow(blue_stack).to receive(:asg_ids) { ['blueASG'] }
      allow(green_stack).to receive(:asg_ids) { ['greenASG'] }
      allow(blue_asg_driver).to receive(:'exists?').and_return(true)
      allow(green_asg_driver).to receive(:'exists?').and_return(true)
      allow(green_asg_driver).to receive(:describe) {{desired: 2, min: 1, max: 3}}
      allow(blue_asg_driver).to receive(:describe) {{desired: 2, min: 1, max: 5}}
      expect(blue_stack).not_to receive(:delete)
      expect(green_stack).not_to receive(:delete)
      expect(blue_stack).not_to receive(:deploy)
      expect(green_stack).not_to receive(:deploy)
      expect{ CfDeployer::DeploymentStrategy.create(app, env, component, context).deploy}.to raise_error("Found both auto-scaling-groups, [\"greenASG\", \"blueASG\"], in green and blue stacks are active. Deployment aborted!")
    end

    context 'multiple ASG' do
      let(:context) {
            {
              :'deployment-strategy' => 'auto-scaling-group-swap',
              :settings => {
                :'auto-scaling-group-name-output' => ['AutoScalingGroupID', 'AlternateASGID']
              }
            }
      }

      it 'should get error containing only "active" ASG if both blue and green stacks are active' do
        allow(blue_stack).to receive(:find_output).with('AlternateASGID'){'AltblueASG'}
        allow(green_stack).to receive(:find_output).with('AlternateASGID'){'AltgreenASG'}
        blue_stack.live!
        green_stack.live!
        alt_blue_asg_driver = double('alt_blue_asg_driver')
        alt_green_asg_driver = double('alt_green_asg_driver')
        allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('AltblueASG') { alt_blue_asg_driver }
        allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
        allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('AltgreenASG') { alt_green_asg_driver }
        allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('greenASG') { green_asg_driver }
        allow(blue_stack).to receive(:asg_ids) { ['blueASG', 'AltblueASG'] }
        allow(green_stack).to receive(:asg_ids) { ['greenASG'] }
        allow(blue_asg_driver).to receive(:'exists?').and_return(true)
        allow(alt_blue_asg_driver).to receive(:'exists?').and_return(true)
        allow(green_asg_driver).to receive(:'exists?').and_return(true)
        allow(alt_green_asg_driver).to receive(:'exists?').and_return(true)
        allow(alt_blue_asg_driver).to receive(:describe) {{desired: 1, min: 1, max: 2}}
        allow(alt_green_asg_driver).to receive(:describe) {{desired: 0, min: 0, max: 0}}
        allow(blue_asg_driver).to receive(:describe) {{desired: 1, min: 1, max: 2}}
        allow(green_asg_driver).to receive(:describe) {{desired: 2, min: 1, max: 5}}
        expect(blue_stack).not_to receive(:delete)
        expect(green_stack).not_to receive(:delete)
        expect(blue_stack).not_to receive(:deploy)
        expect(green_stack).not_to receive(:deploy)
        expect{ CfDeployer::DeploymentStrategy.create(app, env, component, context).deploy}.to raise_error(CfDeployer::DeploymentStrategy::AutoScalingGroupSwap::BothStacksActiveError, "Found both auto-scaling-groups, [\"greenASG\", \"blueASG\", \"AltblueASG\"], in green and blue stacks are active. Deployment aborted!")
      end
    end
  end

  it 'should delete stacks' do
    green_stack.live!
    blue_stack.live!
    allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('greenASG') { green_asg_driver }
    allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
    allow(green_asg_driver).to receive(:describe) { {desired: 0, min: 0, max: 0 } }
    allow(blue_asg_driver).to receive(:describe) { {desired: 1, min: 1, max: 3 } }
    expect(green_stack).to receive(:delete)
    expect(blue_stack).to receive(:delete)
    CfDeployer::DeploymentStrategy.create(app, env, component, context).destroy
  end

  describe '#kill_inactive' do
    context 'when blue stack is active' do
      it 'should kill the green stack' do
        green_stack.live!
        blue_stack.live!
        allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('greenASG') { green_asg_driver }
        allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
        allow(green_asg_driver).to receive(:describe) { {desired: 0, min: 0, max: 0 } }
        allow(blue_asg_driver).to receive(:describe) { {desired: 1, min: 1, max: 3 } }
        expect(green_stack).to receive(:delete)
        expect(blue_stack).not_to receive(:delete)

        CfDeployer::DeploymentStrategy.create(app, env, component, context).kill_inactive
      end
    end

    context 'when green stack is active' do
      it 'should kill the blue stack' do
        green_stack.live!
        blue_stack.live!
        allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('greenASG') { green_asg_driver }
        allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
        allow(blue_asg_driver).to receive(:describe) { {desired: 0, min: 0, max: 0 } }
        allow(green_asg_driver).to receive(:describe) { {desired: 1, min: 1, max: 3 } }
        expect(blue_stack).to receive(:delete)
        expect(green_stack).not_to receive(:delete)

        CfDeployer::DeploymentStrategy.create(app, env, component, context).kill_inactive
      end
    end

    context 'when only one stack exists' do
      it 'should raise an error' do
        green_stack.live!
        blue_stack.die!
        allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('greenASG') { green_asg_driver }
        allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
        allow(blue_asg_driver).to receive(:describe) { {desired: 0, min: 0, max: 0 } }
        allow(green_asg_driver).to receive(:describe) { {desired: 1, min: 1, max: 3 } }

        expect {CfDeployer::DeploymentStrategy.create(app, env, component, context).kill_inactive }.to raise_error CfDeployer::ApplicationError
      end
    end

    context 'when both stacks are active' do
      it 'should raise an error' do
        green_stack.live!
        blue_stack.live!
        allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('greenASG') { green_asg_driver }
        allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
        allow(blue_asg_driver).to receive(:describe) { {desired: 2, min: 1, max: 3 } }
        allow(green_asg_driver).to receive(:describe) { {desired: 1, min: 1, max: 3 } }

        expect {CfDeployer::DeploymentStrategy.create(app, env, component, context).kill_inactive }.to raise_error CfDeployer::DeploymentStrategy::AutoScalingGroupSwap::BothStacksActiveError
      end
    end
  end

  describe '#switch' do
    context 'both stacks are active' do
      it 'should raise an error' do
        green_stack.live!
        blue_stack.live!
        allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('greenASG') { green_asg_driver }
        allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
        allow(green_asg_driver).to receive(:describe) { {desired: 1, min: 1, max: 3 } }
        allow(blue_asg_driver).to receive(:describe) { {desired: 1, min: 1, max: 3 } }

        strategy = CfDeployer::DeploymentStrategy.create(app, env, component, context)
        expect{strategy.switch}.to raise_error 'Found both auto-scaling-groups, ["greenASG", "blueASG"], in green and blue stacks are active. Switch aborted!'
      end
    end

    context 'both stacks do not exist' do
      it 'should raise an error' do
        green_stack.live!
        blue_stack.die!
        allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('greenASG') { green_asg_driver }
        allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
        allow(green_asg_driver).to receive(:describe) { {desired: 1, min: 1, max: 3 } }

        strategy = CfDeployer::DeploymentStrategy.create(app, env, component, context)
        expect{ strategy.switch }.to raise_error 'Only one color stack exists, cannot switch to a non-existent version!'
      end
    end

    context 'green stack is active' do
      it 'should warm up blue stack and cool down green stack' do
        green_stack.live!
        blue_stack.live!
        allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
        allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('greenASG') { green_asg_driver }
        allow(blue_stack).to receive(:asg_ids) { ['blueASG'] }
        allow(green_stack).to receive(:asg_ids) { ['greenASG'] }
        allow(blue_asg_driver).to receive(:'exists?').and_return(false)
        allow(green_asg_driver).to receive(:'exists?').and_return(true)
        options = {desired: 5, min: 3, max: 7}
        allow(green_asg_driver).to receive(:describe) {options}
        allow(blue_asg_driver).to receive(:describe) {{desired: 0, min: 0, max: 0}}

        expect(blue_asg_driver).to receive(:warm_up_cooled_group).with(options)
        expect(green_asg_driver).to receive(:cool_down)

        strategy = CfDeployer::DeploymentStrategy.create(app, env, component, context)
        strategy.switch
      end
    end
  end

  context '#cool_down_active_stack' do
    it 'should cool down only those ASGs which actually exist' do
      blue_stack.live!
      green_stack.die!
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('greenASG') { green_asg_driver }
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
      allow(green_asg_driver).to receive(:describe) { {desired: 0, min: 0, max: 0 } }
      allow(blue_asg_driver).to receive(:describe) { {desired: 1, min: 1, max: 3 } }

      strategy = CfDeployer::DeploymentStrategy.create(app, env, component, context)
      expect(blue_asg_driver).to receive(:cool_down)
      strategy.send(:cool_down_active_stack)
    end
  end

  describe '#asg_driver' do
    it 'returns the same driver for the same aws_group_name' do
      strategy = CfDeployer::DeploymentStrategy.create(app, env, component, context)
      expect(strategy.send(:asg_driver, 'myAsg')).to eql(strategy.send(:asg_driver, 'myAsg'))
    end

    it 'returns a different driver for a different aws_group_name' do
      strategy = CfDeployer::DeploymentStrategy.create(app, env, component, context)
      expect(strategy.send(:asg_driver, 'myAsg')).not_to eql(strategy.send(:asg_driver, 'different'))
    end
  end

  context '#output_value' do

    it 'should get stack output if active stack exists' do
      blue_stack.live!
      green_stack.live!
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('greenASG') { green_asg_driver }
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
      allow(green_asg_driver).to receive(:describe) {{desired: 0, min: 0, max: 0}}
      allow(blue_asg_driver).to receive(:describe) {{desired: 3, min: 1, max: 5}}
      asg_swap = CfDeployer::DeploymentStrategy.create(app, env, component, context)
      asg_swap.output_value("AutoScalingGroupID").should eq("blueASG")
    end

    it 'should get the information where the value comes from if the active stack does not exist' do
      blue_stack.live!
      green_stack.live!
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('greenASG') { green_asg_driver }
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
      allow(green_asg_driver).to receive(:describe) {{desired: 0, min: 0, max: 0}}
      allow(blue_asg_driver).to receive(:describe) {{desired: 0, min: 0, max: 0}}
      asg_swap = CfDeployer::DeploymentStrategy.create(app, env, component, context)
      asg_swap.output_value(:a_key).should eq("The value will be referenced from the output a_key of undeployed component worker")
    end
  end

  context '#status' do
     before :each do
      blue_stack.live!
      green_stack.live!
      allow(blue_stack).to receive(:status) { 'blue deployed' }
      allow(green_stack).to receive(:status) { 'green deployed' }
      allow(blue_stack).to receive(:resource_statuses) { 'blue resources' }
      allow(green_stack).to receive(:resource_statuses) { 'green resources' }
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('greenASG') { green_asg_driver }
      allow(blue_asg_driver).to receive(:describe) {{desired: 3, min: 1, max: 5}}
      allow(green_asg_driver).to receive(:describe) {{desired: 0, min: 0, max: 0}}
      asg_swap = CfDeployer::DeploymentStrategy.create(app, env, component, context)

    end

    it 'should get status for both green and blue stacks' do
      asg_swap = CfDeployer::DeploymentStrategy.create(app, env, component, context)
      expected_result = {
        'BLUE' => {
          :active => true,
          :status => 'blue deployed'
        },
         'GREEN' => {
          :active => false,
          :status => 'green deployed'
        }
      }
      asg_swap.status.should eq(expected_result)
    end

    it 'should get status for both green and blue stacks including resources info' do
      asg_swap = CfDeployer::DeploymentStrategy.create(app, env, component, context)
      expected_result = {
        'BLUE' => {
          :active => true,
          :status => 'blue deployed',
          :resources => 'blue resources'
        },
         'GREEN' => {
          :active => false,
          :status => 'green deployed',
          :resources => 'green resources'
        }
      }
      asg_swap.status(true).should eq(expected_result)
    end
  end

  context 'new subcomponent' do
    it 'should consider a new subcomponent to be non-active in existing stack' do
      asg_swap = CfDeployer::DeploymentStrategy.create(app, env, component, context)
      asg_swap.send(:get_active_asgs, blue_stack).should eq([])
    end
  end
end

require 'functional_spec_helper'

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
    allow(blue_stack).to receive(:resource_statuses) { asg_ids('blueASG') }
    allow(green_stack).to receive(:resource_statuses) { asg_ids('greenASG') }
    allow(CfDeployer::Stack).to receive(:new).with('myapp-dev-worker-B', 'worker', context) { blue_stack }
    allow(CfDeployer::Stack).to receive(:new).with('myapp-dev-worker-G', 'worker', context) { green_stack }
  end

  context 'component exists?' do
    it 'no if no G and B stacks exist' do
      blue_stack.die!
      green_stack.die!
      expect(CfDeployer::DeploymentStrategy.create(app, env, component, context).exists?).to be_falsey
    end

    it 'yes if B stacks exist' do
      blue_stack.live!
      green_stack.die!
      expect(CfDeployer::DeploymentStrategy.create(app, env, component, context).exists?).to be_truthy
    end
    it 'yes if G  stacks exist' do
      blue_stack.die!
      green_stack.live!
      expect(CfDeployer::DeploymentStrategy.create(app, env, component, context).exists?).to be_truthy
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
      expect(@log).to eq('green deleted.blue deleted.')
    end
  end

  context 'on deployment failure' do
    context 'in stack creation' do
      context 'and only one stack is active' do
        it 'should not cool down the only available stack' do
          strategy = create_strategy(blue: :active)
          error = RuntimeError.new("Error before inactive_stack became active")

          expect(strategy).to receive(:create_inactive_stack).and_raise(error)
          expect(strategy).to_not receive(:cool_down)

          ignore_errors { strategy.deploy }
        end

        it 'should report the deployment as a failure' do
          strategy = create_strategy(blue: :active)
          error = RuntimeError.new("Error before inactive_stack became active")

          expect(strategy).to receive(:create_inactive_stack).and_raise(error)
          expect { strategy.deploy }.to raise_error(error)
        end
      end

      context 'and both stacks are active' do
        it 'should cool down inactive stack' do
          strategy = create_strategy(blue: :active)
          inactive_stack = strategy.send(:green_stack)

          expect(strategy).to receive(:create_inactive_stack) do
            activate_stack(inactive_stack)
            raise RuntimeError.new("Error after inactive_stack became active")
          end

          expect(strategy).to receive(:cool_down).with(inactive_stack)
          ignore_errors { strategy.deploy }
        end

        it 'should report the deployment as a failure' do
          strategy = create_strategy(blue: :active)
          inactive_stack = strategy.send(:green_stack)
          error = RuntimeError.new("Error after inactive_stack became active")

          expect(strategy).to receive(:create_inactive_stack) do
            activate_stack(inactive_stack)
            raise error
          end

          allow(strategy).to receive(:cool_down)
          expect { strategy.deploy }.to raise_error(error)
        end
      end
    end

    context 'in asg swap' do
      # This shouldn't be possible - a stack normally becomes active at creation
      context 'and only one stack is active' do
        it 'should not cool down the only available stack' do
          strategy = create_strategy(blue: :active)
          error = RuntimeError.new("Error during swap")

          # The stack would normally be active after create_inactive_stack
          allow(strategy).to receive(:create_inactive_stack)
          expect(strategy).to receive(:swap_group).and_raise(error)
          expect(strategy).to_not receive(:cool_down)

          ignore_errors { strategy.deploy }
        end

        it 'should report the deployment as a failure' do
          strategy = create_strategy(blue: :active)
          error = RuntimeError.new("Error during swap")

          # The stack would normally be active after create_inactive_stack
          allow(strategy).to receive(:create_inactive_stack)
          expect(strategy).to receive(:swap_group).and_raise(error)
          expect(strategy).to_not receive(:cool_down)

          expect { strategy.deploy }.to raise_error(error)
        end
      end

      context 'and both stacks are active' do
        it 'should cool down inactive stack' do
          strategy = create_strategy(blue: :active)
          inactive_stack = strategy.send(:green_stack)
          error = RuntimeError.new("Error during swap")

          allow(strategy).to receive(:create_inactive_stack) { activate_stack(inactive_stack) }
          expect(strategy).to receive(:swap_group).and_raise(error)
          expect(strategy).to receive(:cool_down).with(inactive_stack)

          ignore_errors { strategy.deploy }
        end

        it 'should report the deployment as a failure' do
          strategy = create_strategy(blue: :active)
          inactive_stack = strategy.send(:green_stack)
          error = RuntimeError.new("Error during swap")

          allow(strategy).to receive(:create_inactive_stack) { activate_stack(inactive_stack) }
          expect(strategy).to receive(:swap_group).and_raise(error)
          expect(strategy).to receive(:cool_down).with(inactive_stack)

          expect { strategy.deploy }.to raise_error(error)
        end
      end
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
        allow(blue_stack).to receive(:resource_statuses) { asg_ids('blueASG', 'AltblueASG') }
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
        strategy = create_strategy(blue: :active, green: :active)
        error = 'Found both auto-scaling-groups, ["greenASG", "blueASG"], in green and blue stacks are active. Switch aborted!'

        expect { strategy.switch }.to raise_error(error)
      end
    end

    context 'both stacks do not exist' do
      let(:error) { 'Both stacks must exist to switch.' }

      context '(only green exists)' do
        it 'should raise an error' do
          strategy = create_strategy(green: :active, blue: :dead)

          expect { strategy.switch }.to raise_error(error)
        end
      end

      context '(only blue exists)' do
        it 'should raise an error' do
          strategy = create_strategy(green: :dead, blue: :active)

          expect { strategy.switch }.to raise_error(error)
        end
      end

      context '(no stack exists)' do
        it 'should raise an error' do
          strategy = create_strategy(green: :dead, blue: :dead)

          expect { strategy.switch }.to raise_error(error)
        end
      end
    end

    context 'green stack is active' do
      let(:strategy) { create_strategy(green: :active, blue: :inactive) }

      it 'should warm up blue stack and cool down green stack' do
        active_stack = strategy.send(:green_stack)
        inactive_stack = strategy.send(:blue_stack)

        expect(strategy).to receive(:warm_up_stack).with(inactive_stack, active_stack, true)
        expect(strategy).to receive(:cool_down).with(active_stack)

        strategy.switch
      end

      context 'swap fails' do
        context 'before blue stack becomes active' do
          let(:error) { 'Error before inactive stack becomes active' }

          it 'does not cool down any stack' do
            expect(strategy).to receive(:warm_up_stack).and_raise(error)
            expect(strategy).to_not receive(:cool_down)

            ignore_errors { strategy.switch }
          end

          it 'reports the switch as a failure' do
            expect(strategy).to receive(:warm_up_stack).and_raise(error)
            allow(strategy).to receive(:cool_down)

            expect { strategy.switch }.to raise_error(error)
          end
        end

        context 'after both stacks became active' do
          let(:error) { 'Error after inactive stack becomes active ' }

          it 'cools down the blue stack' do
            expect(strategy).to receive(:warm_up_stack) do
              expect(strategy).to receive(:both_stacks_active?).and_return(true)
              raise error
            end

            inactive_stack = strategy.send(:blue_stack)
            expect(strategy).to receive(:cool_down).with(inactive_stack)

            ignore_errors { strategy.switch }
          end

          it 'reports the switch as a failure' do
            expect(strategy).to receive(:warm_up_stack) do
              expect(strategy).to receive(:both_stacks_active?).and_return(true)
              raise error
            end

            expect { strategy.switch }.to raise_error(error)
          end
        end
      end
    end

    context 'blue stack is active' do
      let(:strategy) { create_strategy(green: :inactive, blue: :active) }

      it 'should warm up green stack and cool down blue stack' do
        active_stack = strategy.send(:blue_stack)
        inactive_stack = strategy.send(:green_stack)

        expect(strategy).to receive(:warm_up_stack).with(inactive_stack, active_stack, true)
        expect(strategy).to receive(:cool_down).with(active_stack)

        strategy.switch
      end

      context 'swap fails' do
        context 'before green stack becomes active' do
          let(:error) { 'Error before inactive stack becomes active' }

          it 'does not cool down any stack' do
            expect(strategy).to receive(:warm_up_stack).and_raise(error)
            expect(strategy).to_not receive(:cool_down)

            ignore_errors { strategy.switch }
          end

          it 'reports the switch as a failure' do
            expect(strategy).to receive(:warm_up_stack).and_raise(error)
            allow(strategy).to receive(:cool_down)

            expect { strategy.switch }.to raise_error(error)
          end
        end

        context 'after both stacks become active' do
          let(:error) { 'Error after inactive stack becomes active ' }

          it 'cools down the green stack' do
            expect(strategy).to receive(:warm_up_stack) do
              expect(strategy).to receive(:both_stacks_active?).and_return(true)
              raise error
            end

            inactive_stack = strategy.send(:green_stack)
            expect(strategy).to receive(:cool_down).with(inactive_stack)

            ignore_errors { strategy.switch }
          end

          it 'reports the switch as a failure' do
            expect(strategy).to receive(:warm_up_stack) do
              expect(strategy).to receive(:both_stacks_active?).and_return(true)
              raise error
            end

            expect { strategy.switch }.to raise_error(error)
          end
        end
      end
    end
  end

  context '#cool_down' do
    it 'should cool down only those ASGs which actually exist' do
      blue_stack.live!
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
      allow(blue_asg_driver).to receive(:describe) { {desired: 1, min: 1, max: 3 } }

      strategy = CfDeployer::DeploymentStrategy.create(app, env, component, context)
      expect(blue_asg_driver).to receive(:cool_down)
      strategy.send(:cool_down, blue_stack)
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
      expect(asg_swap.output_value("AutoScalingGroupID")).to eq("blueASG")
    end

    it 'should get the information where the value comes from if the active stack does not exist' do
      blue_stack.live!
      green_stack.live!
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('greenASG') { green_asg_driver }
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
      allow(green_asg_driver).to receive(:describe) {{desired: 0, min: 0, max: 0}}
      allow(blue_asg_driver).to receive(:describe) {{desired: 0, min: 0, max: 0}}
      asg_swap = CfDeployer::DeploymentStrategy.create(app, env, component, context)
      expect(asg_swap.output_value(:a_key)).to eq("The value will be referenced from the output a_key of undeployed component worker")
    end
  end

  context '#status' do
    before :each do
      blue_stack.live!
      green_stack.live!
      allow(blue_stack).to receive(:status) { 'blue deployed' }
      allow(green_stack).to receive(:status) { 'green deployed' }
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
      expect(asg_swap.status).to eq(expected_result)
    end

    it 'should get status for both green and blue stacks including resources info' do
      asg_swap = CfDeployer::DeploymentStrategy.create(app, env, component, context)
      expected_result = {
          'BLUE' => {
              :active => true,
              :status => 'blue deployed',
              :resources => {
                  :asg_instances => {
                      'blueASG' => nil
                  }
              }
          },
          'GREEN' => {
              :active => false,
              :status => 'green deployed',
              :resources => {
                  :asg_instances => {
                      'greenASG' => nil
                  }
              }
          }
      }
      expect(asg_swap.status(true)).to eq(expected_result)
    end
  end

  context 'new ASG' do
    let(:foo_asg_driver) { double('foo_asg_driver') }
    let(:bar_asg_driver) { double('bar_asg_driver') }

    before :each do
      allow(foo_asg_driver).to receive(:describe) { {min: 1, desired: 2, max: 3} }
      allow(bar_asg_driver).to receive(:describe) { {min: 0, desired: 0, max: 0} }
    end

    it 'should get active ASGs from CF stack' do
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('foo') { foo_asg_driver }
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('bar') { bar_asg_driver }
      allow(blue_stack).to receive(:resource_statuses) { asg_ids('foo', 'bar') }

      asg_swap = CfDeployer::DeploymentStrategy.create(app, env, component, context)
      expect(asg_swap.send(:get_active_asgs, blue_stack)).to eq(['foo'])
    end
  end

  context '#stack_active' do
    it 'should consider a stack active if it has any active ASGs' do
      allow(CfDeployer::Stack).to receive(:new).with('myapp-dev-worker-B', 'worker', context) { blue_stack }
      allow(CfDeployer::Stack).to receive(:new).with('myapp-dev-worker-G', 'worker', context) { green_stack }
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('greenASG') { green_asg_driver }
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
      allow(blue_asg_driver).to receive(:describe) { {min: 1, desired: 2, max: 3} }
      allow(green_asg_driver).to receive(:describe) { {min: 0, desired: 0, max: 0} }

      asg_swap = CfDeployer::DeploymentStrategy.create(app, env, component, context)
      expect(asg_swap.send(:stack_active?, blue_stack)).to be(true)
    end
  end

  def default_options
    {
      app_name: 'app',
      environment: 'environment',
      component: 'component',
      context: {
        :'deployment-strategy' => 'auto-scaling-group-swap',
        :settings => {
          :'auto-scaling-group-name-output' => ['AutoScalingGroupID']
        }
      }
    }
  end

  def create_strategy original_options = {}
    options = default_options.merge(original_options)

    create_stack(:blue, options.delete(:blue) || :dead, options)
    create_stack(:green, options.delete(:green) || :dead, options)

    CfDeployer::DeploymentStrategy.create(options[:app_name], options[:environment], options[:component], options[:context])
  end

  def create_stack color, status = :active, original_options = {}
    options = default_options.merge(original_options)

    stack = Fakes::Stack.new(name: color.to_s, outputs: {'web-elb-name' => "#{color}-elb"}, parameters: { name: color.to_s})

    stack_color_name = (color.to_s == 'green' ? 'G' : 'B')
    stack_name = "#{options[:app_name]}-#{options[:environment]}-#{options[:component]}-#{stack_color_name}"
    allow(CfDeployer::Stack).to receive(:new).with(stack_name, options[:component], options[:context]).and_return(stack)

    stack.tap do
      case status
      when :active; activate_stack(stack)
      when :inactive; activate_stack(stack, { desired: 0, max: 0, min: 0 })
      when :dead; kill_stack(stack)
      else raise "Trying to create stack with unknown status; #{status}"
      end
    end
  end

  def activate_stack stack, instances = {}
    stack.live!

    allow(stack).to receive(:output).with('AutoScalingGroupID').and_return("#{stack.name}ASG")
    allow(stack).to receive(:find_output).with('AutoScalingGroupID').and_return("#{stack.name}ASG")
    allow(stack).to receive(:resource_statuses).and_return(asg_ids("#{stack.name}ASG"))

    asg_driver = double("#{stack.name}_asg_driver")
    instances[:desired] ||= 2
    instances[:min] ||= 1
    instances[:max] ||= 5

    allow(asg_driver).to receive(:describe).and_return(instances)
    allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with("#{stack.name}ASG") { asg_driver }
  end

  def kill_stack stack
    stack.die!
  end
end

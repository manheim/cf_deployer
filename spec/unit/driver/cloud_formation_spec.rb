require 'spec_helper'

describe 'CloudFormation' do
  let(:outputs) { [output1, output2] }
  let(:output1) { double('output1', :output_key => 'key1', :output_value => 'value1')}
  let(:output2) { double('output2', :output_key => 'key2', :output_value => 'value2')}
  let(:parameters) { double('parameters')}
  let(:resource_summaries) { [
      {
          :resource_type => 'AWS::AutoScaling::AutoScalingGroup',
          :physical_resource_id => 'asg_1',
          :resource_status => 'STATUS_1'
      },
      {
          :resource_type => 'AWS::AutoScaling::LaunchConfiguration',
          :physical_resource_id => 'launch_config_1',
          :resource_status => 'STATUS_2'
      },
      {
          :resource_type => 'AWS::AutoScaling::AutoScalingGroup',
          :physical_resource_id => 'asg_2',
          :resource_status => 'STATUS_2'
      }
  ] }
  let(:stack) { double('stack', :stack_name => 'testStack', :outputs => outputs, :parameters => parameters) }
  let(:cloudFormationStacks) { [stack] }
  let(:cloudFormation) {
    double('cloudFormation',
      :describe_stacks => double(:stacks => cloudFormationStacks),
      :list_stack_resources => double(:stack_resource_summaries => resource_summaries)
    )
  }

  before(:each) do
    allow(Aws::CloudFormation::Client).to receive(:new) { cloudFormation }
    allow(cloudFormation).to receive(:create_stack)
    allow(cloudFormation).to receive(:update_stack)
  end

  it 'should get outputs of stack' do
    expect(CfDeployer::Driver::CloudFormation.new('testStack').outputs).to eq({'key1' => 'value1', 'key2' => 'value2'})
  end

  it 'should get parameters of stack' do
    expect(CfDeployer::Driver::CloudFormation.new('testStack').parameters).to eq(parameters)
  end

  context 'update_stack' do
    it 'skips the stack update if dry run is enabled' do
      cloud_formation = CfDeployer::Driver::CloudFormation.new 'my_stack'
      expect(cloud_formation).to receive(:aws_stack).never

      CfDeployer::Driver::DryRun.enable_for do
        cloud_formation.update_stack :template, {}
      end
    end

    it 'returns false if no updates were performed (because of dry run)' do
      cloud_formation = CfDeployer::Driver::CloudFormation.new 'my_stack'
      result = nil

      CfDeployer::Driver::DryRun.enable_for do
        result = cloud_formation.update_stack :template, {}
      end

      expect(result).to be_falsey
    end

    it 'returns false if no updates were performed (because no difference in template)' do
      cloud_formation = CfDeployer::Driver::CloudFormation.new 'my_stack'
      expect(cloudFormation).to receive(:update_stack).and_raise(Aws::CloudFormation::Errors::ValidationError.new(nil, 'No updates are to be performed'))
      result = nil

      CfDeployer::Driver::DryRun.disable_for do
        result = cloud_formation.update_stack :template, {}
      end

      expect(result).to be_falsey
    end

    it 'returns true when updates are performed' do
      cloud_formation = CfDeployer::Driver::CloudFormation.new 'my_stack'
      result = nil

      CfDeployer::Driver::DryRun.disable_for do
        result = cloud_formation.update_stack :template, {}
      end

      expect(cloudFormation).to have_received(:update_stack)
      expect(result).to be_truthy
    end

  end

  context 'resource_statuses' do
    it 'should get resource statuses' do
      expected = {
          'AWS::AutoScaling::AutoScalingGroup' => {
              'asg_1' => 'STATUS_1',
              'asg_2' => 'STATUS_2'
          },
          'AWS::AutoScaling::LaunchConfiguration' => {
              'launch_config_1' => 'STATUS_2'
          }
      }

      expect(CfDeployer::Driver::CloudFormation.new('testStack').resource_statuses).to eq(expected)
    end
  end
end

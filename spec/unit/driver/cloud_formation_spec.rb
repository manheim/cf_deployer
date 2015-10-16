require 'spec_helper'

describe 'CloudFormation' do
  let(:outputs) { [output1, output2] }
  let(:output1) { double('output1', :key => 'key1', :value => 'value1')}
  let(:output2) { double('output2', :key => 'key2', :value => 'value2')}
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
  let(:stack) { double('stack', :outputs => outputs, :parameters => parameters, :resource_summaries => resource_summaries) }
  let(:cloudFormation) {
    double('cloudFormation',
           :stacks =>
           {'testStack' => stack
           })
  }

  before(:each) do
    allow(AWS::CloudFormation).to receive(:new) { cloudFormation }
  end

  it 'should get outputs of stack' do
    CfDeployer::Driver::CloudFormation.new('testStack').outputs.should eq({'key1' => 'value1', 'key2' => 'value2'})
  end

  it 'should get parameters of stack' do
    CfDeployer::Driver::CloudFormation.new('testStack').parameters.should eq(parameters)
  end

  context 'resources' do
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

      CfDeployer::Driver::CloudFormation.new('testStack').resource_statuses.should eq(expected)
    end

    it 'should get summaries of stack' do
      CfDeployer::Driver::CloudFormation.new('testStack').resource_summaries.should eq(resource_summaries)
    end

    it 'should get summaries of stack filtered by type' do
      expected = resource_summaries.clone
      expected.delete_at(1)
      actual = CfDeployer::Driver::CloudFormation.new('testStack').resource_summaries('AWS::AutoScaling::AutoScalingGroup')
      actual.should eq(expected)
    end
  end
end

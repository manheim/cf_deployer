require 'spec_helper'

describe 'CloudFormation' do
  let(:outputs) { [output1, output2] }
  let(:output1) { double('output1', :key => 'key1', :value => 'value1')}
  let(:output2) { double('output2', :key => 'key2', :value => 'value2')}
  let(:parameters) { double('parameters')}
  let(:stack) { double('stack', :outputs => outputs, :parameters => parameters) }
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

  context 'resource_statuses' do
    it 'should be tested' do
      false
    end
  end
end

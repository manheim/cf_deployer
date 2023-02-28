require 'spec_helper'

describe 'CreateOrUpdate Strategy' do
  before :each do
    @after_create_hook = double('after_create_hook')
    @after_update_hook = double('after_update_hook')
    @before_destroy_hook = double('before_destroy_hook')
    allow(CfDeployer::Hook).to receive(:new).with(:'after-create', 'after-create'){ @after_create_hook }
    allow(CfDeployer::Hook).to receive(:new).with(:'after-update', 'after-update'){ @after_update_hook }
    allow(CfDeployer::Hook).to receive(:new).with(:'before-destroy', 'before-destroy') { @before_destroy_hook }
    @context = {
      :application => 'myApp',
      :environment => 'uat',
      :components =>
        { :base => {
          :settings => {},
          :'deployment-strategy' => 'create-or-update',
          :'after-create' => 'after-create',
          :'after-update' => 'after-update',
          :'before-destroy' => 'before-destroy'
        }
      }
    }
    @stack = double('stack')
    @create_or_update = CfDeployer::DeploymentStrategy.create(@context[:application], @context[:environment], 'base', @context[:components][:base])
    allow(CfDeployer::Stack).to receive(:new).with('myApp-uat-base','base', @context[:components][:base]){ @stack}
    allow(@stack).to receive(:parameters){ {'vpc' => 'myvpc'}}
    allow(@stack).to receive(:outputs){ {'ELBName' => 'myelb'}}
  end

  it 'should deploy stack and run the after-create hook if no stack exists' do
    hook_context = nil
    expect(@after_create_hook).to receive(:run) do |given_context|
      hook_context = given_context
    end
    expect(@stack).to receive(:exists?).and_return(false)
    expect(@stack).to receive(:deploy)
    @create_or_update.deploy
    expect(hook_context[:parameters]).to eq( {'vpc' => 'myvpc'} )
    expect(hook_context[:outputs]).to eq( {'ELBName' => 'myelb'} )
  end

  it 'should deploy stack and run the after-update hook if a stack already exists' do
    hook_context = nil
    expect(@after_update_hook).to receive(:run) do |given_context|
      hook_context = given_context
    end
    expect(@stack).to receive(:exists?).and_return(true)
    expect(@stack).to receive(:deploy)
    @create_or_update.deploy
    expect(hook_context[:parameters]).to eq( {'vpc' => 'myvpc'} )
    expect(hook_context[:outputs]).to eq( {'ELBName' => 'myelb'} )
  end

  context 'warm up auto scaling group' do

    let(:asg_driver) { double('asg_driver') }

    it 'should warm up the stack if any auto-scaling groups are given' do
      context = @context[:components][:base]
      context[:settings] = {}
      context[:settings][:'auto-scaling-group-name-output'] = ['AutoScalingGroupID']
      expect(@stack).to receive(:exists?).and_return(false)
      allow(@stack).to receive(:find_output).with('AutoScalingGroupID') { 'asg_name' }
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('asg_name') { asg_driver }
      allow(asg_driver).to receive(:describe) { {desired:2, min:1, max:3} }
      allow(@after_create_hook).to receive(:run).with(anything)
      allow(@stack).to receive(:deploy)
      create_or_update = CfDeployer::DeploymentStrategy.create(@context[:application], @context[:environment], 'base', context)
      expect(asg_driver).to receive(:warm_up).with 2
      create_or_update.deploy
    end
  end

  it 'should tell if stack exists' do
    expect(@stack).to receive(:exists?){true}
    expect(@create_or_update.exists?).to eq(true)
  end

  it 'should get stack output' do
    allow(@stack).to receive(:exists?){true}
    expect(@stack).to receive(:output).with(:a_key){ "output_value" }
    expect(@create_or_update.output_value(:a_key)).to eq("output_value")
  end

  it 'should get the information where the value comes from if the stack does not exist' do
    allow(@stack).to receive(:exists?){false}
    expect(@stack).not_to receive(:output).with(anything)
    expect(@create_or_update.output_value(:a_key)).to eq("The value will be referenced from the output a_key of undeployed component base")
  end

  context '#destroy' do
    it 'should destroy stack' do
      allow(@stack).to receive(:exists?){ true}
      allow(@stack).to receive(:parameters) { {}}
      allow(@stack).to receive(:outputs) {{}}
      expect(@before_destroy_hook).to receive(:run).with(anything)
      expect(@stack).to receive(:delete)
      @create_or_update.destroy
    end
  end

  describe '#kill_inactive' do
    it 'should raise an error' do
      expect { @create_or_update.kill_inactive }.to raise_error CfDeployer::ApplicationError
    end
  end

  context '#switch' do
    it 'should raise an error' do
      expect{ @create_or_update.switch }.to raise_error 'There is no inactive version to switch to for Create or Update Deployments.  Redeploy the version you want'
    end
  end

  context '#status' do
    before :each do
      allow(@stack).to receive(:status) { 'deployed' }
      allow(@stack).to receive(:name) { 'base-uat' }
      allow(@stack).to receive(:exists?) { true }
    end
    it 'should get status from stack' do
      expect(@create_or_update.status).to eq({ 'base-uat' => {status: 'deployed'}})
    end
    it 'should get status from stack including resource info' do
      allow(@stack).to receive(:resource_statuses) { 'resource1' }
      expect(@create_or_update.status(true)).to eq({ 'base-uat' => {status: 'deployed', resources: 'resource1'}})
    end
  end
end

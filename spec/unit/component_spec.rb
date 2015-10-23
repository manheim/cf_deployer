require 'spec_helper'

describe "component" do
  before :each do
    @strategy = double('deployment_strategy')

    allow(CfDeployer::DeploymentStrategy).to receive(:create).and_return(@strategy)

       @context = {
          :'deployment-strategy' => 'create-or-update',
          :inputs => {
            :'vpc-subnets' => {
              :component => 'base',
              :'output-key' => 'subnets'
            }
           }
          }
    @base = CfDeployer::Component.new('myApp', 'uat', 'base', {})
    @db = CfDeployer::Component.new('myApp', 'uat', 'db', {})

    @web = CfDeployer::Component.new('myApp', 'uat', 'web', @context)
    @web.dependencies << @base
    @web.dependencies << @db
    @base.children << @web
    @db.children << @web
  end

  context 'json' do

    it 'should revolve settings from parent components if parent components has been deployed' do
      allow(@base).to receive(:exists?){ true }
      allow(@base).to receive(:output_value).with('subnets') { 'abcd1234, edfas1234' }
      expect(CfDeployer::ConfigLoader).to receive(:component_json).with('web', @context)
      @web.json

      expect(@context[:inputs][:'vpc-subnets']).to eq('abcd1234, edfas1234')
    end
  end


  it "should destroy component" do
    expect(@strategy).to receive(:destroy)
    @web.destroy
  end

  it 'should not destroy a component that is depended on' do
    allow(@web).to receive(:exists?){ true }
    expect(@strategy).not_to receive(:destroy)
    expect{ @base.destroy }.to raise_error("Unable to destroy #{@base.name}, it is depended on by other components")
  end

  it "should get output value" do
    expect(@strategy).to receive(:output_value).with('key1'){ 'value1' }
    @web.output_value('key1')
  end

  it "deployment should only deploy depends-on if the depends-on do not exists" do
    expect(@base).to receive(:exists?){ false }
    expect(@db).to receive(:exists?) { true }
    expect(@base).to receive(:deploy)
    expect(@db).to_not receive(:deploy)
    expect(@strategy).to receive(:deploy)
    expect(@base).to receive(:output_value).with('subnets') { 'abcd1234, edfas1234' }
    @web.deploy

    expect(@context[:inputs][:'vpc-subnets']).to eq('abcd1234, edfas1234')
  end

  it "should ask strategy if component exists" do
     expect(@strategy).to receive(:exists?){ true }
     expect(@web.exists?).to eq(true)
  end

  it "should find direct dependencies" do
    web = CfDeployer::Component.new('myApp', 'uat', 'web', {})
    base = CfDeployer::Component.new('myApp', 'uat', 'base', {})
    web.dependencies << base

    expect(web.depends_on?(base)).to eq(true)
  end

  it "should find transitive dependencies" do
    web = CfDeployer::Component.new('myApp', 'uat', 'web', {})
    haproxy = CfDeployer::Component.new('myApp', 'uat', 'haproxy', {})
    base = CfDeployer::Component.new('myApp', 'uat', 'base', {})

    haproxy.dependencies << base
    web.dependencies << haproxy

    expect(web.depends_on?(base)).to eq(true)
  end

  it "should find cyclic dependency" do
    web = CfDeployer::Component.new('myApp', 'uat', 'web', {})
    haproxy = CfDeployer::Component.new('myApp', 'uat', 'haproxy', {})
    base = CfDeployer::Component.new('myApp', 'uat', 'base', {})
    foo = CfDeployer::Component.new('myApp', 'uat', 'foo', {})

    haproxy.dependencies << base
    web.dependencies << haproxy
    base.dependencies << web

    expect{haproxy.depends_on? foo}.to raise_error("Cyclic dependency")
  end

  describe '#status' do
    it "should ask strategy for status" do
       expect(@strategy).to receive(:status){ true }
       @web.status false
    end

    it "should pass get_resource_statuses down to the strategy" do
       expect(@strategy).to receive(:status).with(true)
       @web.status(true)
    end
  end

  describe '#kill_inactive' do
    it 'should tell the strategy to kill the inactive piece' do
      expect(@strategy).to receive(:kill_inactive)
      @web.kill_inactive
    end
  end

  describe '#switch' do
    context 'if no stack exists' do
      it 'should raise an error that there is no stack for the component' do
        allow(@strategy).to receive(:exists?) { false }
        expect(@strategy).not_to receive(:switch)
        expect { @web.switch }.to raise_error 'No stack exists for component: web'
      end
    end

    context 'a stack exists' do
      it 'should use the deployment strategy to switch' do
        allow(@strategy).to receive(:exists?) { true }
        expect(@strategy).to receive(:switch)
        @web.switch
      end
    end
  end

  describe '#run_hook' do
    it 'should resolve_settings before running the hook' do
      expect(@web).to receive(:resolve_settings)
      expect(@strategy).to receive(:run_hook).with(:'after-work')
      @web.run_hook :'after-work'
    end
  end
end

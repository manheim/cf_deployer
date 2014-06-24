require 'spec_helper'

describe 'Deployment Strategy' do
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

  it "should create Create-Or-Update strategy" do
    expect(CfDeployer::DeploymentStrategy::CreateOrUpdate).to receive(:new)
    CfDeployer::DeploymentStrategy.create('myApp', 'uat', 'base', @context[:components][:base])
  end

  it "should create Auto-Scaling-Group-Swap strategy" do
    expect(CfDeployer::DeploymentStrategy::AutoScalingGroupSwap).to receive(:new)
    CfDeployer::DeploymentStrategy.create('myApp', 'uat', 'db', @context[:components][:db])
  end
  it "should create Cname-Swap strategy" do
    expect(CfDeployer::DeploymentStrategy::CnameSwap).to receive(:new)
    CfDeployer::DeploymentStrategy.create('myApp', 'uat', 'web', @context[:components][:web])
  end
end

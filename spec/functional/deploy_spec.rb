require 'functional_spec_helper'

describe 'Deploy' do
  context 'create-or-update' do

    let(:asg_driver) { double('asg_driver') }
    let(:stack) { Fakes::Stack.new(name: 'stack', outputs: {'AutoScalingGroupID' => 'myASG'})}

    it 'should create a stack in Cloud Formation' do
      stack.die!
      allow(CfDeployer::Stack).to receive(:new).with('cf-deployer-sample-create-or-update-test-web', 'web', anything()) { stack }
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('myASG') { asg_driver }
      allow(asg_driver).to receive(:describe) {{desired: 1, min: 1, max: 2}}
      allow(asg_driver).to receive(:warm_up).with(1)
      CfDeployer::CLI.start(['deploy', 'test', 'web', '-f', 'samples/create-or-update/cf_deployer.yml'])
      expect(stack).to be_deployed
    end
  end

  context 'cname-swap' do
    let(:blue_asg_driver) { double('blue_asg_driver') }
    let(:green_asg_driver) { double('green_asg_driver') }
    let(:dns_driver) { double('route53') }
    let(:elb_driver) { double('elb') }
    let(:blue_stack)  { Fakes::Stack.new(name: 'BLUE', outputs: {'ELBName' => 'BLUE-elb', 'AutoScalingGroupName' => 'blueASG'}, parameters: {:name => 'blue'}) }
    let(:green_stack) { Fakes::Stack.new(name: 'GREEN', outputs: {'ELBName' => 'GREEN-elb', 'AutoScalingGroupName' => 'greenASG'}, parameters: {:name => 'green'}) }

    before :each do
      allow(Kernel).to receive(:sleep)
    end
    it 'should recreate inactive stack and set CNAME map to its ELB dns' do
      allow(CfDeployer::Stack).to receive(:new).with('cf-deployer-sample-cname-swap-dev-web-B', 'web', anything()) { blue_stack }
      allow(CfDeployer::Stack).to receive(:new).with('cf-deployer-sample-cname-swap-dev-web-G', 'web', anything()) { green_stack }
      allow(CfDeployer::Driver::Elb).to receive(:new) { elb_driver }
      allow(CfDeployer::Driver::Route53).to receive(:new) { dns_driver }
      allow(dns_driver).to receive(:find_alias_target).with('aws-dev.manheim.com', 'cf-deployer-test.aws-dev.manheim.com'){ 'BLUE-elb.aws-dev.manheim.com' }
      allow(elb_driver).to receive(:find_dns_and_zone_id).with('BLUE-elb') { {:dns_name => 'blue-elb.aws-dev.manheim.com', :canonical_hosted_zone_name_id => 'BLUE111'}}
      allow(elb_driver).to receive(:find_dns_and_zone_id).with('GREEN-elb') { {:dns_name => 'green-elb.aws-dev.manheim.com', :canonical_hosted_zone_name_id => 'GREEN111'}}
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('greenASG') { green_asg_driver }
      allow(green_asg_driver).to receive(:describe) {{desired: 0, min: 0, max: 0}}
      allow(blue_asg_driver).to receive(:describe) {{desired: 2, min: 1, max: 5}}
      allow(dns_driver).to receive(:set_alias_target).with('aws-dev.manheim.com', 'cf-deployer-test.aws-dev.manheim.com', 'GREEN111', 'green-elb.aws-dev.manheim.com')
      expect(green_asg_driver).to receive(:warm_up).with(2)
      CfDeployer::CLI.start(['deploy', 'dev', 'web', '-f', 'samples/cname-swap/cf_deployer.yml'])
      expect(green_stack).to be_deleted
      expect(green_stack).to be_deployed
    end
  end

  context 'autoscaling-swap' do
    let(:blue_asg_driver) { double('blue_asg_driver') }
    let(:green_asg_driver) { double('green_asg_driver') }
    let(:blue_stack)  { Fakes::Stack.new(name: 'BLUE', outputs: {'web-elb-name' => 'BLUE-elb', 'AutoScalingGroupName' => 'blueASG'}, parameters: { name: 'blue'}) }
    let(:green_stack)  { Fakes::Stack.new(name: 'GREEN', outputs: {'web-elb-name' => 'GREEN-elb', 'AutoScalingGroupName' => 'greenASG'}, parameters: { name: 'green'}) }
    let(:base_stack)  { Fakes::Stack.new(name: 'base') }

    it 'should re-create and warm up inactive stack and cool down the active stack' do
      allow(CfDeployer::Stack).to receive(:new).with('cf-deployer-sample-asg-swap-dev-web-B', 'web', anything) { blue_stack }
      allow(CfDeployer::Stack).to receive(:new).with('cf-deployer-sample-asg-swap-dev-web-G', 'web', anything) { green_stack }
      allow(CfDeployer::Stack).to receive(:new).with('cf-deployer-sample-asg-swap-dev-base', 'base', anything) { base_stack }
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('greenASG') { green_asg_driver }
      allow(blue_stack).to receive(:resource_statuses) { asg_ids 'blueASG' }
      allow(green_stack).to receive(:resource_statuses) { asg_ids 'greenASG' }
      allow(blue_asg_driver).to receive(:describe) {{desired: 0, min: 0, max: 0}}
      allow(green_asg_driver).to receive(:describe) {{desired: 2, min: 1, max: 5}}
      expect(blue_asg_driver).to receive(:warm_up).with(2)

      CfDeployer::CLI.start(['deploy', 'dev', 'web', '-f', 'samples/simple/cf_deployer.yml'])
      expect(blue_stack).to be_deleted
      expect(blue_stack).to be_deployed
    end
  end
end

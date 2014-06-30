require 'functional_spec_helper'

describe 'Kill Inactive' do
  context 'create-or-update' do
    let(:stack) { Fakes::Stack.new(name: 'stack', outputs: {'AutoScalingGroupID' => 'myASG'})}

    it 'should raise an error that there is no inactive for create-or-update staks' do
      stack.die!
      allow(CfDeployer::Stack).to receive(:new).with('cf-deployer-sample-create-or-update-test-web', 'web', anything()) { stack }
      expect { CfDeployer::CLI.start(['kill_inactive', 'test', 'web', '-f', 'samples/create-or-update/cf_deployer.yml']) }.to raise_error CfDeployer::ApplicationError, 'There is no inactive version to kill for Create or Update Deployments.'
    end
  end

  context 'cname-swap' do
    let(:blue_stack)  { Fakes::Stack.new(name: 'BLUE', outputs: {'ELBName' => 'BLUE-elb', 'AutoScalingGroupID' => 'blueASG'}, parameters: {:name => 'blue'}) }
    let(:green_stack) { Fakes::Stack.new(name: 'GREEN', outputs: {'ELBName' => 'GREEN-elb', 'AutoScalingGroupID' => 'greenASG'}, parameters: {:name => 'green'}) }

    it 'should delete the stack that is not being pointed to by dns' do
      blue_stack.live!
      green_stack.live!
      elb_driver = double('elb_driver')
      allow(CfDeployer::Driver::Elb).to receive(:new) { elb_driver }
      allow(elb_driver).to receive(:find_dns_and_zone_id).with('BLUE-elb') { {:dns_name => 'blue-elb.aws.amazon.com', :canonical_hosted_zone_name_id => 'BLUE111'}}
      allow(elb_driver).to receive(:find_dns_and_zone_id).with('GREEN-elb') { {:dns_name => 'green-elb.aws.amazon.com', :canonical_hosted_zone_name_id => 'GREEN111'}}
      allow(CfDeployer::Stack).to receive(:new).with('cf-deployer-sample-cname-swap-test-web-B', 'web', anything) { blue_stack }
      allow(CfDeployer::Stack).to receive(:new).with('cf-deployer-sample-cname-swap-test-web-G', 'web', anything) { green_stack }
      dns_driver = double('route53 driver')
      allow(CfDeployer::Driver::Route53).to receive(:new) { dns_driver }
      allow(dns_driver).to receive(:find_alias_target).with('zhao.com', 'test1.zhao.com'){ 'BLUE-elb.aws.amazon.com' }

      CfDeployer::CLI.start(['kill_inactive', 'test', 'web', '-f', 'samples/cname-swap/cf_deployer.yml'])
      expect(green_stack).to be_deleted
      expect(blue_stack).not_to be_deleted
    end
  end

  context 'asg-swap' do
    let(:blue_stack)  { Fakes::Stack.new(name: 'BLUE', outputs: {'ELBName' => 'BLUE-elb', 'AutoScalingGroupName' => 'blueASG'}, parameters: {:name => 'blue'}) }
    let(:green_stack) { Fakes::Stack.new(name: 'GREEN', outputs: {'ELBName' => 'GREEN-elb', 'AutoScalingGroupName' => 'greenASG'}, parameters: {:name => 'green'}) }
    let(:blue_asg_driver) { double('blue_asg_driver') }
    let(:green_asg_driver) { double('green_asg_driver') }

    it 'should delete the stack that has no active instances' do
      blue_stack.live!
      green_stack.live!
      allow(CfDeployer::Stack).to receive(:new).with('cf-deployer-sample-asg-swap-test-web-B', 'web', anything) { blue_stack }
      allow(CfDeployer::Stack).to receive(:new).with('cf-deployer-sample-asg-swap-test-web-G', 'web', anything) { green_stack }
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('greenASG') { green_asg_driver }
      allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
      allow(green_asg_driver).to receive(:describe) { {desired: 0, min: 0, max: 0} }
      allow(blue_asg_driver).to receive(:describe) { {desired: 1, min: 1, max: 2} }
      CfDeployer::CLI.start(['kill_inactive', 'test', 'web', '-f', 'samples/simple/cf_deployer.yml'])
      expect(green_stack).to be_deleted
      expect(blue_stack).not_to be_deleted
    end
  end
end

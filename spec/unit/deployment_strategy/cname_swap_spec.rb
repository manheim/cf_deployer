require 'spec_helper'

describe CfDeployer::DeploymentStrategy::CnameSwap do

  let(:dns_driver) { double('route53') }
  let(:elb_driver) { double('elb') }
  let(:blue_asg_driver) { double('blue_asg_driver') }
  let(:green_asg_driver) { double('green_asg_driver') }
  let(:blue_stack)  { Fakes::Stack.new(name: 'BLUE', outputs: {'web-elb-name' => 'BLUE-elb', 'AutoScalingGroupID' => 'blueASG'}, parameters: {:name => 'blue'}) }
  let(:green_stack) { Fakes::Stack.new(name: 'GREEN', outputs: {'web-elb-name' => 'GREEN-elb', 'AutoScalingGroupID' => 'greenASG'}, parameters: {:name => 'green'}) }

  before do
    allow(Kernel).to receive(:sleep)
    @context =
        {
          :'deployment-strategy' => 'cname-swap',
          :dns_driver => dns_driver,
          :elb_driver => elb_driver,
          :settings              => {
            :'dns-fqdn'        => 'test.foobar.com',
            :'dns-zone'        => 'foobar.com',
            :'elb-name-output' => 'web-elb-name',
            :'dns-driver'      => CfDeployer::Defaults::DNSDriver
          }
        }

    allow(CfDeployer::Stack).to receive(:new).with('myapp-dev-web-B', 'web', anything()) { blue_stack }
    allow(CfDeployer::Stack).to receive(:new).with('myapp-dev-web-G', 'web', anything()) { green_stack }
    allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('blueASG') { blue_asg_driver }
    allow(CfDeployer::Driver::AutoScalingGroup).to receive(:new).with('greenASG') { green_asg_driver }
    allow(elb_driver).to receive(:find_dns_and_zone_id).with('BLUE-elb') { {:dns_name => 'blue-elb.aws.amazon.com', :canonical_hosted_zone_name_id => 'BLUE111'}}
    allow(elb_driver).to receive(:find_dns_and_zone_id).with('GREEN-elb') { {:dns_name => 'green-elb.aws.amazon.com', :canonical_hosted_zone_name_id => 'GREEN111'}}
  end

  context "hooks" do
    let(:before_destroy_hook) { double('before_destroy_hook') }
    let(:after_create_hook) { double('after_create_hook') }
    let(:after_swap_hook) { double('after_swap_hook') }

    before :each do
      allow(CfDeployer::Hook).to receive(:new).with(:'before-destroy', 'before-destroy'){ before_destroy_hook }
      allow(CfDeployer::Hook).to receive(:new).with(:'after-create', 'after-create'){ after_create_hook }
      allow(CfDeployer::Hook).to receive(:new).with(:'after-swap', 'after-swap'){ after_swap_hook }
      allow(dns_driver).to receive(:set_alias_target)
      @context[:'before-destroy'] = 'before-destroy'
      @context[:'after-create'] = 'after-create'
      @context[:'after-swap'] = 'after-swap'
    end

    it "should call hooks" do
      allow(dns_driver).to receive(:find_alias_target).with('foobar.com', 'test.foobar.com'){ 'BLUE-elb.aws.amazon.com' }
      cname_swap = CfDeployer::DeploymentStrategy.create('myapp', 'dev', 'web', @context)
      expect(before_destroy_hook).to receive(:run).with(@context).twice
      expect(after_create_hook).to receive(:run).with(@context)
      expect(after_swap_hook).to receive(:run).with(@context)
      cname_swap.deploy
    end

    it 'should call hooks when destroying green and blue stacks' do
      @log = ''
      cname_swap = CfDeployer::DeploymentStrategy.create('myapp', 'dev', 'web', @context)
      allow(blue_stack).to receive(:delete)
      allow(green_stack).to receive(:delete)
      allow(before_destroy_hook).to receive(:run) do |arg|
        @log += "#{arg[:parameters][:name]} deleted."
      end
      expect(dns_driver).to receive(:delete_record_set).with('foobar.com', 'test.foobar.com')
      cname_swap.destroy
      expect(@log).to eq('green deleted.blue deleted.')
    end
  end

  context "deploy" do

    it "deploys green when blue is active" do
      allow(dns_driver).to receive(:find_alias_target).with('foobar.com', 'test.foobar.com'){ 'BLUE-elb.aws.amazon.com' }
      expect(dns_driver).to receive(:set_alias_target).with('foobar.com', 'test.foobar.com', 'GREEN111', 'green-elb.aws.amazon.com')
      cname_swap = CfDeployer::DeploymentStrategy.create('myapp', 'dev', 'web', @context)
      cname_swap.deploy

      expect(green_stack).to be_deployed
      expect(blue_stack).to_not be_deployed
    end

    it "deletes blue after deploying green" do
      allow(dns_driver).to receive(:find_alias_target).with('foobar.com', 'test.foobar.com'){ 'BLUE-elb.aws.amazon.com' }
      allow(dns_driver).to receive(:set_alias_target).with('foobar.com', 'test.foobar.com', 'GREEN111', 'green-elb.aws.amazon.com')
      cname_swap = CfDeployer::DeploymentStrategy.create('myapp', 'dev', 'web', @context)
      cname_swap.deploy

      expect(blue_stack).to be_deleted
    end

    it "should not delete blue after deploying green if keep-previous-stack is specified" do
      allow(dns_driver).to receive(:find_alias_target).with('foobar.com', 'test.foobar.com'){ 'BLUE-elb.aws.amazon.com' }
      allow(dns_driver).to receive(:set_alias_target).with('foobar.com', 'test.foobar.com', 'GREEN111', 'green-elb.aws.amazon.com')
      @context[:settings][:'keep-previous-stack'] = true
      cname_swap = CfDeployer::DeploymentStrategy.create('myapp', 'dev', 'web', @context)
      cname_swap.deploy

      expect(blue_stack).to_not be_deleted
    end

    it "deploys blue when green is active" do
      allow(dns_driver).to receive(:find_alias_target).with('foobar.com', 'test.foobar.com'){ 'GREEN-elb.aws.amazon.com' }
      expect(dns_driver).to receive(:set_alias_target).with('foobar.com', 'test.foobar.com', 'BLUE111', 'blue-elb.aws.amazon.com')

      cname_swap = CfDeployer::DeploymentStrategy.create('myapp', 'dev', 'web', @context)

      cname_swap.deploy

      expect(blue_stack).to be_deployed
      expect(green_stack).to_not be_deployed
    end

    it "deletes the inactive stack before deployment" do
      allow(dns_driver).to receive(:find_alias_target).with('foobar.com', 'test.foobar.com'){ 'BLUE-elb.aws.amazon.com' }
      allow(dns_driver).to receive(:set_alias_target).with('foobar.com', 'test.foobar.com', 'GREEN111', 'green-elb.aws.amazon.com')
      cname_swap = CfDeployer::DeploymentStrategy.create('myapp', 'dev', 'web', @context)
      cname_swap.deploy

      expect(green_stack).to be_deleted
      expect(green_stack).to be_deployed
    end

    it "does not delete the green-inactive stack before deployment if that stack does not exist" do
      green_stack.die!

      allow(dns_driver).to receive(:find_alias_target).with('foobar.com', 'test.foobar.com'){ 'BLUE-elb.aws.amazon.com' }
      allow(dns_driver).to receive(:set_alias_target)
      cname_swap = CfDeployer::DeploymentStrategy.create('myapp', 'dev', 'web', @context)
      cname_swap.deploy

      expect(green_stack).to_not be_deleted
    end

    it "does not delete the blue-inactive stack before deployment if that stack does not exist" do
      blue_stack.die!

      allow(dns_driver).to receive(:find_alias_target).with('foobar.com', 'test.foobar.com'){ 'GREEN-elb.aws.amazon.com' }
      allow(dns_driver).to receive(:set_alias_target)

      cname_swap = CfDeployer::DeploymentStrategy.create('myapp', 'dev', 'web', @context)
      cname_swap.deploy

      expect(blue_stack).to_not be_deleted
    end

    it 'should warm up any auto scaling groups to previous colors levels' do
      blue_stack.die!
      green_stack.live!

      allow(dns_driver).to receive(:find_alias_target).with('foobar.com', 'test.foobar.com'){ 'GREEN-elb.aws.amazon.com' }
      allow(dns_driver).to receive(:set_alias_target)
      allow(green_asg_driver).to receive(:describe) { { desired: 3, min: 1, max: 5 } }
      @context[:settings][:'auto-scaling-group-name-output'] = ['AutoScalingGroupID']
      expect(blue_asg_driver).to receive(:warm_up).with 3
      cname_swap = CfDeployer::DeploymentStrategy.create('myapp', 'dev', 'web', @context)
      cname_swap.deploy
    end

    it 'should warm up any auto scaling groups to desired number when no previous color exists' do
      blue_stack.die!
      green_stack.die!

      allow(dns_driver).to receive(:set_alias_target)
      allow(blue_asg_driver).to receive(:describe) { { desired: 2, min: 1, max: 5 } }
      @context[:settings][:'auto-scaling-group-name-output'] = ['AutoScalingGroupID']
      expect(blue_asg_driver).to receive(:warm_up).with 2
      cname_swap = CfDeployer::DeploymentStrategy.create('myapp', 'dev', 'web', @context)
      cname_swap.deploy
    end

    it 'should not warm up if there are no auto scaling groups given' do
      blue_stack.die!
      green_stack.die!

      allow(dns_driver).to receive(:set_alias_target)
      allow(blue_asg_driver).to receive(:describe) { { desired: 2, min: 1, max: 5 } }
      expect(blue_asg_driver).not_to receive(:warm_up)
      cname_swap = CfDeployer::DeploymentStrategy.create('myapp', 'dev', 'web', @context)
      cname_swap.deploy
    end
  end

  context 'exists?' do
    it 'no, if green stack and blue stack do not exist' do
      blue_stack.die!
      green_stack.die!
      cname_swap = CfDeployer::DeploymentStrategy.create('myapp', 'dev', 'web', @context)
      expect(cname_swap.exists?).to be_falsey
    end

    it 'yes, if green stack exists and blue stack does not' do
      blue_stack.die!
      cname_swap = CfDeployer::DeploymentStrategy.create('myapp', 'dev', 'web', @context)
      expect(cname_swap.exists?).to be_truthy
    end

    it 'yes, if blue stack exists and green stack does not' do
      green_stack.die!
      cname_swap = CfDeployer::DeploymentStrategy.create('myapp', 'dev', 'web', @context)
      expect(cname_swap.exists?).to be_truthy
    end
  end

  context '#destroy' do
    it 'should destroy green and blue stacks' do
      cname_swap = CfDeployer::DeploymentStrategy.create('myapp', 'dev', 'web', @context)
      expect(blue_stack).to receive(:delete)
      expect(green_stack).to receive(:delete)
      expect(dns_driver).to receive(:delete_record_set).with('foobar.com', 'test.foobar.com')
      cname_swap.destroy
    end
  end

  context 'dns_driver' do
    it 'should use a different driver class if the dns-driver setting is used' do
      my_context = @context.clone
      my_context.delete :dns_driver
      my_context[:settings][:'dns-driver'] = 'CfDeployer::Driver::Verisign'
      cname_swap = CfDeployer::DeploymentStrategy.create('myapp', 'dev', 'web', my_context)
      expect(cname_swap.send(:dns_driver).class.to_s).to eq(my_context[:settings][:'dns-driver'])
    end
  end

  describe '#kill_inactive' do
    let(:cname_swap) { CfDeployer::DeploymentStrategy.create('myapp', 'dev', 'web', @context) }

    context 'when blue stack is active' do
      it 'should destroy the green stack' do
        green_stack.live!
        blue_stack.live!
        allow(dns_driver).to receive(:find_alias_target).with('foobar.com', 'test.foobar.com'){ 'BLUE-elb.aws.amazon.com' }
        expect(green_stack).to receive(:delete)
        cname_swap.kill_inactive
      end
    end

    context 'when green stack is active' do
      it 'should destroy the blue stack' do
        green_stack.live!
        blue_stack.live!
        allow(dns_driver).to receive(:find_alias_target).with('foobar.com', 'test.foobar.com'){ 'GREEN-elb.aws.amazon.com' }
        expect(blue_stack).to receive(:delete)
        cname_swap.kill_inactive
      end
    end

    context 'when green stack is active and blue stack does not exist' do
      it 'should raise an error' do
        green_stack.live!
        blue_stack.die!
        allow(dns_driver).to receive(:find_alias_target).with('foobar.com', 'test.foobar.com'){ 'GREEN-elb.aws.amazon.com' }
        expect(blue_stack).not_to receive(:delete)
        expect { cname_swap.kill_inactive }.to raise_error CfDeployer::ApplicationError
      end
    end
  end

  describe '#switch' do
    let(:cname_swap) { CfDeployer::DeploymentStrategy.create('myapp', 'dev', 'web', @context) }
    context 'if no inactive version exists' do
      it 'should raise an error' do
        green_stack.die!
        blue_stack.live!
        expect { cname_swap.switch }.to raise_error 'There is only one color stack active, you cannot switch back to a non-existent version'
      end
    end

    context 'if an inactive version exists' do
      it 'should swap the cname to the inactive version' do
        green_stack.live!
        blue_stack.live!
        allow(dns_driver).to receive(:find_alias_target).with('foobar.com', 'test.foobar.com'){ 'BLUE-elb.aws.amazon.com' }
        expect(dns_driver).to receive(:set_alias_target).with('foobar.com', 'test.foobar.com', 'GREEN111', 'green-elb.aws.amazon.com')
        cname_swap.switch
      end
    end
  end

  context '#output_value' do

    it 'should get stack output if active stack exists' do
      allow(dns_driver).to receive(:find_alias_target).with('foobar.com', 'test.foobar.com'){ 'BLUE-elb.aws.amazon.com' }
      cname_swap = CfDeployer::DeploymentStrategy.create('myapp', 'dev', 'web', @context)
      expect(cname_swap.output_value("AutoScalingGroupID")).to eq("blueASG")
    end

    it 'should get the information where the value comes from if the active stack does not exist' do
      allow(dns_driver).to receive(:find_alias_target).with('foobar.com', 'test.foobar.com'){ '' }
      cname_swap = CfDeployer::DeploymentStrategy.create('myapp', 'dev', 'web', @context)
      expect(cname_swap.output_value(:a_key)).to eq("The value will be referenced from the output a_key of undeployed component web")
    end
  end
end

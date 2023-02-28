require 'spec_helper'

describe CfDeployer::Driver::Route53 do
  subject { CfDeployer::Driver::Route53.new }

  describe ".find_alias_target" do
    it "should raise an error when the target zone cannot be found" do
      route53 = double('route53')
      allow(Aws::Route53::Client).to receive(:new) { route53 }

      allow(route53).to receive_message_chain(:list_hosted_zones_by_name, :hosted_zones) { [] }

      expect { subject.find_alias_target('abc.com', 'foo') }.to raise_error('Target zone not found!')
    end

    it "should get empty alias target when the target host cannot be found" do
      resource_record_sets = double('resource_record_sets', :resource_record_sets => [])
      zone = double('zone', :id => '/hostedzone/hostedzoneid', :name => 'target.com.')

      route53 = double('route53')
      allow(Aws::Route53::Client).to receive(:new) { route53 }
      allow(route53).to receive_message_chain(:list_hosted_zones_by_name, :hosted_zones) { [zone] }
      allow(route53).to receive(:list_resource_record_sets).with(hosted_zone_id: '/hostedzone/hostedzoneid') { resource_record_sets }

      expect(subject.find_alias_target('target.com', 'foo')).to be_nil
    end

    it "should get alias target" do
      host = double('host', :name => 'foo.target.com.', :alias_target => { :dns_name => 'abc.com.'})
      resource_record_sets = double('resource_record_sets', :resource_record_sets => [host])
      zone = double('zone', :id => '/hostedzone/hostedzoneid', :name => 'target.com.')
      route53 = double('route53')
      allow(route53).to receive_message_chain(:list_hosted_zones_by_name, :hosted_zones) { [zone] }
      allow(route53).to receive(:list_resource_record_sets).with(hosted_zone_id: '/hostedzone/hostedzoneid') { resource_record_sets }
      allow(Aws::Route53::Client).to receive(:new) { route53 }

      expect(subject.find_alias_target('Target.com', 'Foo.target.com')).to eq('abc.com')
    end

    it "should get a nil alias target when the record exists but has no alias target" do
      host = double('host', :name => 'foo.target.com.', :alias_target => nil)
      resource_record_sets = double('resource_record_sets', :resource_record_sets => [host])
      zone = double('zone', :id => '/hostedzone/hostedzoneid', :name => 'target.com.')
      route53 = double('route53')
      allow(route53).to receive_message_chain(:list_hosted_zones_by_name, :hosted_zones) { [zone] }
      allow(route53).to receive(:list_resource_record_sets).with(hosted_zone_id: '/hostedzone/hostedzoneid') { resource_record_sets }
      allow(Aws::Route53::Client).to receive(:new) { route53 }

      expect(subject.find_alias_target('target.com', 'foo.target.com')).to be_nil
    end

    it "should get alias target when zone and host name having trailing dot" do
      host = double('host', :name => 'foo.target.com.', :alias_target => { :dns_name => 'abc.com.'})
      resource_record_sets = double('resource_record_sets', :resource_record_sets => [host])
      zone = double('zone', :id => '/hostedzone/hostedzoneid', :name => 'target.com.')
      route53 = double('route53')
      allow(route53).to receive_message_chain(:list_hosted_zones_by_name, :hosted_zones) { [zone] }
      allow(route53).to receive(:list_resource_record_sets).with(hosted_zone_id: '/hostedzone/hostedzoneid') { resource_record_sets }
      allow(Aws::Route53::Client).to receive(:new) { route53 }

      expect(subject.find_alias_target('target.com.', 'foo.target.com.')).to eq('abc.com')
    end

  end

  describe ".set_alias_target" do
    it "should raise an error when the target-zone cannot be found" do
      route53 = double('route53')
      allow(Aws::Route53::Client).to receive(:new) { route53 }

      allow(route53).to receive_message_chain(:list_hosted_zones_by_name, :hosted_zones) { [] }

      expect { subject.set_alias_target('abc.com', 'foo', 'abc', 'def') }.to raise_error('Target zone not found!')
    end

    it "should attempt multiple times" do
      failing_route53 = Fakes::AWSRoute53.new(times_to_fail: 5, hosted_zones: [double(id: '/hostedzone/hostedzoneid', name: 'abc.com.', path: '')])
      route53_driver = CfDeployer::Driver::Route53.new(failing_route53)

      allow(route53_driver).to receive(:sleep)
      route53_driver.set_alias_target('abc.com', 'foo', 'abc', 'def')

      expect(failing_route53.fail_counter).to eq(6)
    end

    it "should raise an exception when failing more than 20 times" do
      failing_route53 = Fakes::AWSRoute53.new(times_to_fail: 21, hosted_zones: [double(id: '/hostedzone/hostedzoneid', name: 'abc.com.', path: '')])
      route53_driver = CfDeployer::Driver::Route53.new(failing_route53)

      allow(route53_driver).to receive(:sleep)
      expect { route53_driver.set_alias_target('abc.com', 'foo', 'abc', 'def') }.to raise_error('Failed to update Route53 alias target record!')
    end
  end
end

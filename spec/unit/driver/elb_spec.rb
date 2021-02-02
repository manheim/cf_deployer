require 'spec_helper'

describe CfDeployer::Driver::Elb do
  it 'should get dns name and hosted zone id' do
    elb = double('elasticloadbalancing', :dns_name => 'mydns', :canonical_hosted_zone_name_id => 'zone_id')

    aws = double('aws')

    elb_name = 'myelb'
    load_balancer_descriptions = double('elb', :load_balancer_descriptions => [elb])

    expect(Aws::ElasticLoadBalancing::Client).to receive(:new){aws}
    expect(aws).to receive(:describe_load_balancers).with(:load_balancer_names => [elb_name]) { load_balancer_descriptions }

    expect(CfDeployer::Driver::Elb.new.find_dns_and_zone_id(elb_name)).to eq({:dns_name => 'mydns', :canonical_hosted_zone_name_id => 'zone_id'})
  end
end

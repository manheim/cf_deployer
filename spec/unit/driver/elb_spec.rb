require 'spec_helper'

describe CfDeployer::Driver::Elb do
  it 'should get dns name and hosted zone id' do
    elb = double('elb', :dns_name => 'mydns', :canonical_hosted_zone_name_id => 'zone_id')
    aws = double('aws', :load_balancers => {'myelb' => elb})
    elb_name = 'myelb'
    expect(AWS::ELB).to receive(:new){aws}
    expect(CfDeployer::Driver::Elb.new.find_dns_and_zone_id(elb_name)).to eq({:dns_name => 'mydns', :canonical_hosted_zone_name_id => 'zone_id'})
  end
end

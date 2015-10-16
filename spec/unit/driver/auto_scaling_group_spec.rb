require 'spec_helper'

describe 'Autoscaling group driver' do
  let(:group) { double('group', :desired_capacity => 2, :min_size => 1, :max_size => 4)}
  let(:scaling) { double('scaling', :groups => { 'myAsg' => group}) }
  let(:ec2_instance1) { double('ec2_instance1') }
  let(:ec2_instance2) { double('ec2_instance2') }
  let(:ec2_instance3) { double('ec2_instance3') }
  let(:ec2_instance4) { double('ec2_instance4') }
  let(:instance1) { double('instance1', :health_status => 'HEALTHY', :ec2_instance => ec2_instance1)}
  let(:instance2) { double('instance2', :health_status => 'HEALTHY', :ec2_instance => ec2_instance2)}
  let(:instance3) { double('instance3', :health_status => 'HEALTHY', :ec2_instance => ec2_instance3)}
  let(:instance4) { double('instance4', :health_status => 'HEALTHY', :ec2_instance => ec2_instance4)}
  let(:load_balancer) { double('load_balancer', :instances => [instance1, instance2, instance3, instance4]) }

  before :each do
    allow(AWS::AutoScaling).to receive(:new) { scaling }
    allow(group).to receive(:load_balancers) { [] }
    allow(group).to receive(:auto_scaling_instances) { [] }
    allow(group).to receive(:ec2_instances) { [] }
    @driver = CfDeployer::Driver::AutoScalingGroup.new('myAsg', 1)
  end

  it 'should describe group' do
    @driver.describe.should eq({ min: 1, max: 4, desired: 2})
  end

  it 'should determine exists from AWS API object' do
    allow(group).to receive(:exists?).and_return(true)
    expect(@driver.exists?).to be(true)
  end

  describe '#warm_up' do
    it 'should warm up the group to the desired size' do
      expect(group).to receive(:auto_scaling_instances){[instance1, instance2]}
      expect(group).to receive(:set_desired_capacity).with(2)
      @driver.warm_up 2
    end

    it 'should wait for the warm up of the group even if desired is the same as the minimum' do
      expect(group).to receive(:auto_scaling_instances){[instance2]}
      expect(group).to receive(:set_desired_capacity).with(1)
      @driver.warm_up 1
    end

    it 'should ignore warming up if desired number is less than min size of the group' do
      expect(group).not_to receive(:set_desired_capacity)
      @driver.warm_up 0
    end

    it 'should warm up to maximum if desired number is greater than maximum size of group' do
      expect(group).to receive(:auto_scaling_instances){[instance1, instance2, instance3, instance4]}
      expect(group).to receive(:set_desired_capacity).with(4)
      @driver.warm_up 5
    end
  end

  describe '#healthy_instance_count' do
    it 'should respond with the number of instances that are HEALTHY' do
      instance5 =  double('instance1', :health_status => 'UNHEALTHY')
      allow(group).to receive(:auto_scaling_instances){[instance1, instance2, instance3, instance4, instance5]}
      expect(@driver.send(:healthy_instance_count)).to eql 4
    end

    it 'health check should be resilient against intermittent errors' do
      instance5 = double('instance5')
      expect(instance5).to receive(:health_status).and_raise(StandardError)
      allow(group).to receive(:auto_scaling_instances){ [ instance5 ] }
      expect(@driver.send(:healthy_instance_count)).to eql -1
    end

    context 'when an elb is associated with the auto scaling group' do
      it 'should not include instances that are HEALTHY but not associated with the elb' do
        instance_collection = double('instance_collection', :health => [{:instance => ec2_instance1, :state => 'InService'}])
        load_balancer = double('load_balancer', :instances => instance_collection)
        allow(group).to receive(:load_balancers) { [load_balancer] }
        allow(group).to receive(:auto_scaling_instances) { [instance1, instance2] }

        expect(@driver.send(:healthy_instance_count)).to eql 1
      end

      it 'should only include instances registered with an elb that are InService' do
        allow(group).to receive(:auto_scaling_instances) { [instance1, instance2, instance3] }
        instance_collection = double('instance_collection', :health => [{:instance => ec2_instance1, :state => 'InService'},
                                                                        {:instance => ec2_instance2, :state => 'OutOfService'},
                                                                        {:instance => ec2_instance3, :state => 'OutOfService'}])
        load_balancer = double('load_balancer', :instances => instance_collection)
        allow(group).to receive(:load_balancers) { [load_balancer] }

        expect(@driver.send(:healthy_instance_count)).to eql 1
      end
    end

    context 'when there are multiple elbs for an auto scaling group' do
      it 'should not include instances that are not registered with all load balancers' do
        instance_collection1 = double('instance_collection1', :health => [{:instance => ec2_instance1, :state => 'InService'}])
        instance_collection2 = double('instance_collection2', :health => [])
        load_balancer1 = double('load_balancer1', :instances => instance_collection1)
        load_balancer2 = double('load_balancer2', :instances => instance_collection2)
        allow(group).to receive(:load_balancers) { [load_balancer1, load_balancer2] }
        allow(group).to receive(:auto_scaling_instances) { [instance1] }

        expect(@driver.send(:healthy_instance_count)).to eql 0
      end
    end
  end

  describe '#cool_down' do
    it 'should cool down group' do
      expect(group).to receive(:update).with({min_size: 0, max_size: 0})
      expect(group).to receive(:set_desired_capacity).with(0)
      @driver.cool_down
    end
  end

  describe '#warm_up_cooled_group' do
    it 'should set min, max, and desired from a hash' do
      hash = {:max => 5, :min => 2, :desired => 3}
      allow(group).to receive(:auto_scaling_instances){[instance1, instance2, instance3]}
      expect(group).to receive(:update).with({:min_size => 2, :max_size => 5})
      expect(group).to receive(:set_desired_capacity).with(3)
      @driver.warm_up_cooled_group hash
    end
  end

  describe '#instance_statuses' do
    it 'should get the status for any EC2 instances' do
      aws_instance = double AWS::EC2::Instance
      expect(aws_instance).to receive(:id) { 'i-abcd1234' }
      allow(@driver).to receive(:ec2_instances) { [ aws_instance ] }

      returned_status = { :status => :some_status }
      cfd_instance = double CfDeployer::Driver::Instance
      expect(CfDeployer::Driver::Instance).to receive(:new).with(aws_instance) { cfd_instance }
      expect(cfd_instance).to receive(:status) { returned_status }
      expect(@driver.instance_statuses).to eq( { 'i-abcd1234' => returned_status } )
    end
  end
end

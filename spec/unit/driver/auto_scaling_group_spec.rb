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

  describe '#warm_up' do
    it 'should warm up the group to the desired size' do
      expect(group).to receive(:set_desired_capacity).with(2)
      expect(@driver).to receive(:wait_for_desired_capacity)
      @driver.warm_up 2
    end

    it 'should wait for the warm up of the group even if desired is the same as the minimum' do
      expect(group).to receive(:set_desired_capacity).with(1)
      expect(@driver).to receive(:wait_for_desired_capacity)
      @driver.warm_up 1
    end

    it 'should ignore warming up if desired number is less than min size of the group' do
      expect(group).not_to receive(:set_desired_capacity)
      expect(@driver).not_to receive(:wait_for_desired_capacity)
      @driver.warm_up 0
    end

    it 'should warm up to maximum if desired number is greater than maximum size of group' do
      expect(group).to receive(:set_desired_capacity).with(4)
      expect(@driver).to receive(:wait_for_desired_capacity)
      @driver.warm_up 5
    end
  end

  describe '#healthy_instance_ids' do
    it 'returns the ids of all instances that are healthy' do
      instance1 =  double('instance1', :health_status => 'HEALTHY', id: 'instance1')
      instance2 =  double('instance2', :health_status => 'HEALTHY', id: 'instance2')
      instance3 =  double('instance3', :health_status => 'UNHEALTHY', id: 'instance3')
      instance4 =  double('instance4', :health_status => 'HEALTHY', id: 'instance4')
      allow(group).to receive(:auto_scaling_instances){[instance1, instance2, instance3, instance4]}

      expect(@driver.healthy_instance_ids).to eql ['instance1', 'instance2', 'instance4']
    end

    it 'returns the ids of all instances that are healthy (case insensitive)' do
      instance1 =  double('instance1', :health_status => 'HealThy', id: 'instance1')
      allow(group).to receive(:auto_scaling_instances){[instance1]}

      expect(@driver.healthy_instance_ids).to eql ['instance1']
    end
  end

  describe '#in_service_instance_ids' do
    context 'when there are no load balancers' do
      it 'returns no ids' do
        allow(group).to receive(:load_balancers).and_return([])

        expect(@driver.in_service_instance_ids).to eq []
      end
    end

    context 'when there is only 1 elb' do
      it 'returns the ids of all instances that are in service' do
        health1 = { state: 'InService', instance: double('i1', id: 'instance1') }
        health2 = { state: 'OutOfService', instance: double('i2', id: 'instance2') }
        health3 = { state: 'InService', instance: double('i3', id: 'instance3') }
        health4 = { state: 'InService', instance: double('i4', id: 'instance4') }

        instance_collection = double('instance_collection', health: [health1, health2, health3, health4])
        elb = double('elb', instances: instance_collection)
        allow(group).to receive(:load_balancers).and_return([ elb ])

        expect(@driver.in_service_instance_ids).to eql ['instance1', 'instance3', 'instance4']
      end
    end

    context 'when there are multiple elbs' do
      it 'returns only the ids of instances that are in all ELBs' do
        health1 = { state: 'InService', instance: double('i1', id: 'instance1') }
        health2 = { state: 'InService', instance: double('i2', id: 'instance2') }
        health3 = { state: 'InService', instance: double('i3', id: 'instance3') }
        health4 = { state: 'InService', instance: double('i4', id: 'instance4') }
        health5 = { state: 'InService', instance: double('i5', id: 'instance5') }

        instance_collection1 = double('instance_collection1', health: [health1, health2, health3])
        instance_collection2 = double('instance_collection2', health: [health2, health3, health4])
        instance_collection3 = double('instance_collection3', health: [health2, health3, health5])
        elb1 = double('elb1', instances: instance_collection1)
        elb2 = double('elb2', instances: instance_collection2)
        elb3 = double('elb3', instances: instance_collection3)
        allow(group).to receive(:load_balancers).and_return([ elb1, elb2, elb3 ])

        # Only instance 2 and 3 are associated with all ELB's
        expect(@driver.in_service_instance_ids).to eql ['instance2', 'instance3']
      end

      it 'returns only the ids instances that are InService in all ELBs' do
        health11 = { state: 'OutOfService', instance: double('i1', id: 'instance1') }
        health12 = { state: 'InService', instance: double('i2', id: 'instance2') }
        health13 = { state: 'InService', instance: double('i3', id: 'instance3') }

        health21 = { state: 'InService', instance: double('i1', id: 'instance1') }
        health22 = { state: 'InService', instance: double('i2', id: 'instance2') }
        health23 = { state: 'OutOfService', instance: double('i3', id: 'instance3') }

        health31 = { state: 'InService', instance: double('i1', id: 'instance1') }
        health32 = { state: 'InService', instance: double('i2', id: 'instance2') }
        health33 = { state: 'InService', instance: double('i3', id: 'instance3') }

        instance_collection1 = double('instance_collection1', health: [health11, health12, health13])
        instance_collection2 = double('instance_collection2', health: [health21, health22, health23])
        instance_collection3 = double('instance_collection3', health: [health31, health32, health33])

        elb1 = double('elb1', instances: instance_collection1)
        elb2 = double('elb2', instances: instance_collection2)
        elb3 = double('elb3', instances: instance_collection3)

        allow(group).to receive(:load_balancers).and_return([ elb1, elb2, elb3 ])

        # Only instance 2 is InService across all ELB's
        expect(@driver.in_service_instance_ids).to eql ['instance2']
      end
    end
  end

  describe '#healthy_instance_count' do
    context 'when there are no load balancers' do
      it 'should return the number of healthy instances' do
        healthy_instance_ids = ['1', '3', '4', '5']
        allow(@driver).to receive(:load_balancers).and_return([])
        expect(@driver).to receive(:healthy_instance_ids).and_return(healthy_instance_ids)

        expect(@driver.healthy_instance_count).to eql(healthy_instance_ids.count)
      end
    end

    context 'when load balancers exist' do
      it 'should return the number of instances that are both healthy, and in service' do
        healthy_instance_ids = ['1', '3', '4', '5']
        in_service_instance_ids = ['3', '4']
        allow(@driver).to receive(:load_balancers).and_return(double('elb', empty?: false))
        expect(@driver).to receive(:healthy_instance_ids).and_return(healthy_instance_ids)
        expect(@driver).to receive(:in_service_instance_ids).and_return(in_service_instance_ids)

        # Only instances 3 and 4 are both healthy and in service
        expect(@driver.healthy_instance_count).to eql(2)
      end
    end

    it 'health check should be resilient against intermittent errors' do
      expect(@driver).to receive(:healthy_instance_ids).and_raise("Some error")
      expect(@driver.healthy_instance_count).to eql -1
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
      expect(@driver).to receive(:warm_up).with(3)
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

  describe '#wait_for_desired_capacity' do
    it 'completes if desired capacity reached' do
      expect(@driver).to receive(:desired_capacity_reached?).and_return(true)

      @driver.wait_for_desired_capacity
    end

    it 'times out if desired capacity is not reached' do
      expect(@driver).to receive(:desired_capacity_reached?).and_return(false)

      expect { @driver.wait_for_desired_capacity }.to raise_error(Timeout::Error)
    end
  end

  describe '#desired_capacity_reached?' do
    it 'returns true if healthy instance count matches desired capacity' do
      expected_number = 5

      expect(group).to receive(:desired_capacity).and_return(expected_number)
      expect(@driver).to receive(:healthy_instance_count).and_return(expected_number)

      expect(@driver.desired_capacity_reached?).to be_true
    end

    it 'returns false if healthy instance count is less than desired capacity' do
      expected_number = 5

      expect(group).to receive(:desired_capacity).and_return(expected_number)
      expect(@driver).to receive(:healthy_instance_count).and_return(expected_number - 1)

      expect(@driver.desired_capacity_reached?).to be_false
    end

    it 'returns true if healthy instance count is more than desired capacity' do
      expected_number = 5

      expect(group).to receive(:desired_capacity).and_return(expected_number)
      expect(@driver).to receive(:healthy_instance_count).and_return(expected_number + 1)

      expect(@driver.desired_capacity_reached?).to be_true
    end
  end
end

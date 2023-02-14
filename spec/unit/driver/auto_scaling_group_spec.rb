require 'spec_helper'

describe 'Autoscaling group driver' do
  let(:group) { double('group', :desired_capacity => 2, :min_size => 1, :max_size => 4)}
  let(:ec2_instance1) { double('ec2_instance1') }
  let(:ec2_instance2) { double('ec2_instance2') }
  let(:ec2_instance3) { double('ec2_instance3') }
  let(:ec2_instance4) { double('ec2_instance4') }
  let(:instance1) { double('instance1', :id => 'instance1', :health_status => 'HEALTHY', :ec2_instance => ec2_instance1)}
  let(:instance2) { double('instance2', :id => 'instance2', :health_status => 'HEALTHY', :ec2_instance => ec2_instance2)}
  let(:instance3) { double('instance3', :id => 'instance3', :health_status => 'HEALTHY', :ec2_instance => ec2_instance3)}
  let(:instance4) { double('instance4', :id => 'instance4', :health_status => 'HEALTHY', :ec2_instance => ec2_instance4)}
  let(:load_balancer) { double('load_balancer', :instances => [instance1, instance2, instance3, instance4]) }
  let(:elb_driver) { double(Aws::ElasticLoadBalancing::Client) }

  before :each do
    allow(Aws::ElasticLoadBalancing::Client).to receive(:new) { elb_driver }
    allow(group).to receive(:load_balancer_names) { [] }
    allow(group).to receive(:instances) { [] }
    allow(Aws::AutoScaling::AutoScalingGroup).to receive(:new).with('myAsg') { group }
    @driver = CfDeployer::Driver::AutoScalingGroup.new('myAsg', 1)
  end

  it 'should describe group' do
    expect(@driver.describe).to eq({ min: 1, max: 4, desired: 2})
  end

  describe '#warm_up' do
    it 'should warm up the group to the desired size' do
      expect(group).to receive(:set_desired_capacity).with({desired_capacity: 2})
      expect(@driver).to receive(:wait_for_desired_capacity)
      @driver.warm_up 2
    end

    it 'should wait for the warm up of the group even if desired is the same as the minimum' do
      expect(group).to receive(:set_desired_capacity).with({desired_capacity: 1})
      expect(@driver).to receive(:wait_for_desired_capacity)
      @driver.warm_up 1
    end

    it 'should ignore warming up if desired number is less than min size of the group' do
      expect(group).not_to receive(:set_desired_capacity)
      expect(@driver).not_to receive(:wait_for_desired_capacity)
      @driver.warm_up 0
    end

    it 'should warm up to maximum if desired number is greater than maximum size of group' do
      expect(group).to receive(:set_desired_capacity).with({desired_capacity: 4})
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
      allow(group).to receive(:instances){[instance1, instance2, instance3, instance4]}

      expect(@driver.healthy_instance_ids).to eql ['instance1', 'instance2', 'instance4']
    end

    it 'returns the ids of all instances that are healthy (case insensitive)' do
      instance1 =  double('instance1', :health_status => 'HealThy', id: 'instance1')
      allow(group).to receive(:instances){[instance1]}

      expect(@driver.healthy_instance_ids).to eql ['instance1']
    end
  end

  describe '#in_service_instance_ids' do
    context 'when there are no load balancers' do
      it 'returns no ids' do
        allow(group).to receive(:load_balancer_names).and_return([])

        expect(@driver.in_service_instance_ids).to eq []
      end
    end

    context 'when there is only 1 elb' do
      let(:elb1_instance_health) { double('elb1_instance_health') }

      before(:each) do
        allow(group).to receive(:load_balancer_names).and_return(['elb1'])
        allow(elb_driver).to receive(:describe_instance_health).with(load_balancer_name: 'elb1') { elb1_instance_health }
      end

      it 'returns the ids of all instances that are in service' do
        health1 = double(:state => 'InService', instance_id: 'instance1')
        health2 = double(:state => 'OutOfService', instance_id: 'instance2')
        health3 = double(:state => 'InService', instance_id: 'instance3')
        health4 = double(:state => 'InService', instance_id: 'instance4')

        allow(elb1_instance_health).to receive(:instance_states) { [health1, health2, health3, health4] }
        allow(group).to receive(:load_balancer_names).and_return([ 'elb1' ])

        expect(@driver.in_service_instance_ids).to eql ['instance1', 'instance3', 'instance4']
      end
    end

    context 'when there are multiple elbs' do
      let(:elb1_instance_health) { double('elb1_instance_health') }
      let(:elb2_instance_health) { double('elb2_instance_health') }
      let(:elb3_instance_health) { double('elb3_instance_health') }

      before(:each) do
        allow(group).to receive(:load_balancer_names).and_return(['elb1', 'elb2', 'elb3'])
        allow(elb_driver).to receive(:describe_instance_health).with(load_balancer_name: 'elb1') { elb1_instance_health }
        allow(elb_driver).to receive(:describe_instance_health).with(load_balancer_name: 'elb2') { elb2_instance_health }
        allow(elb_driver).to receive(:describe_instance_health).with(load_balancer_name: 'elb3') { elb3_instance_health }
      end

      it 'returns only the ids of instances that are in all ELBs' do
        health1 = double(state: 'InService', instance_id: 'instance1')
        health2 = double(state: 'InService', instance_id: 'instance2')
        health3 = double(state: 'InService', instance_id: 'instance3')
        health4 = double(state: 'InService', instance_id: 'instance4')
        health5 = double(state: 'InService', instance_id: 'instance5')

        allow(elb1_instance_health).to receive(:instance_states) { [health1, health2, health3] }
        allow(elb2_instance_health).to receive(:instance_states) { [health2, health3, health4] }
        allow(elb3_instance_health).to receive(:instance_states) { [health2, health3, health5] }

        # Only instance 2 and 3 are associated with all ELB's
        expect(@driver.in_service_instance_ids).to eql ['instance2', 'instance3']
      end

      it 'returns only the ids instances that are InService in all ELBs' do
        health11 = double(state: 'OutOfService', instance_id: 'instance1')
        health12 = double(state: 'InService', instance_id: 'instance2')
        health13 = double(state: 'InService', instance_id: 'instance3')

        health21 = double(state: 'InService', instance_id: 'instance1')
        health22 = double(state: 'InService', instance_id: 'instance2')
        health23 = double(state: 'OutOfService', instance_id: 'instance3')

        health31 = double(state: 'InService', instance_id: 'instance1')
        health32 = double(state: 'InService', instance_id: 'instance2')
        health33 = double(state: 'InService', instance_id: 'instance3')

        allow(elb1_instance_health).to receive(:instance_states) { [health11, health12, health13] }
        allow(elb2_instance_health).to receive(:instance_states) { [health21, health22, health23] }
        allow(elb3_instance_health).to receive(:instance_states) { [health31, health32, health33] }

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
        allow(@driver).to receive(:load_balancer_names).and_return(['elb1'])
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
      expect(group).to receive(:set_desired_capacity).with({desired_capacity: 0})
      @driver.cool_down
    end
  end

  describe '#warm_up_cooled_group' do
    it 'should set min, max, and desired from a hash' do
      hash = {:max => 5, :min => 2, :desired => 3}
      allow(group).to receive(:instances){[instance1, instance2, instance3]}
      expect(group).to receive(:update).with({:min_size => 2, :max_size => 5})
      expect(@driver).to receive(:warm_up).with(3)
      @driver.warm_up_cooled_group hash
    end
  end

  describe '#instance_statuses' do
    it 'should get the status for any EC2 instances' do
      allow(@driver).to receive(:instances) { [ instance1 ] }

      returned_status = { :status => :some_status }
      cfd_instance = double CfDeployer::Driver::Instance
      expect(CfDeployer::Driver::Instance).to receive(:new).with(instance1.id) { cfd_instance }
      expect(cfd_instance).to receive(:status) { returned_status }
      expect(@driver.instance_statuses).to eq( { 'instance1' => returned_status } )
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

      expect(@driver.desired_capacity_reached?).to be_truthy
    end

    it 'returns false if healthy instance count is less than desired capacity' do
      expected_number = 5

      expect(group).to receive(:desired_capacity).and_return(expected_number)
      expect(@driver).to receive(:healthy_instance_count).and_return(expected_number - 1)

      expect(@driver.desired_capacity_reached?).to be_falsey
    end

    it 'returns true if healthy instance count is more than desired capacity' do
      expected_number = 5

      expect(group).to receive(:desired_capacity).and_return(expected_number)
      expect(@driver).to receive(:healthy_instance_count).and_return(expected_number + 1)

      expect(@driver.desired_capacity_reached?).to be_truthy
    end
  end
end

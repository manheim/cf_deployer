require 'spec_helper'

describe CfDeployer::Driver::Instance do
  context '#status' do
    it 'should build the right hash of instance info' do
      expected = { :status => :pending,
                   :public_ip_address => '4.3.2.1',
                   :private_ip_address => '192.168.1.10',
                   :image_id => 'ami-testami',
                   :key_pair => 'test_pair'
                 }


      instance = Fakes::Instance.new expected.merge( { :id => 'i-wxyz1234' } )
      allow(instance).to receive(:state) { :pending }
      expect(Aws::EC2::Instance).to receive(:new).with('i-wxyz1234') { instance }

      instance_status = CfDeployer::Driver::Instance.new('i-wxyz1234').status

      expected.each do |key, val|
        expect(instance_status[key]).to eq(val)
      end
    end
  end
end
require 'aws_call_count_spec_helper'

describe CfDeployer::Driver::AutoScalingGroup do
  it 'makes the minimum number of calls to AWS when there are 4 instances in the ASG' do
    asg = 'myASG'

    override_aws_environment(AWS_REGION: 'us-east-1') do
      logs = nil
      allow(CfDeployer::Log).to receive(:info) { |message| logs = message }
      driver = CfDeployer::Driver::AutoScalingGroup.new asg
      VCR.use_cassette("aws_call_count/driver/auto_scaling_group/healthy_instance_count") do
        expect(driver.send(:healthy_instance_count)).to equal(4), "Logs: #{logs}"
      end

      expect(WebMock).to have_requested(:post, "https://autoscaling.us-east-1.amazonaws.com/").times(5)
      expect(WebMock).to have_requested(:post, "https://elasticloadbalancing.us-east-1.amazonaws.com/").times(4)
    end
  end
end

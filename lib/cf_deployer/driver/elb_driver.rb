module CfDeployer
  module Driver
    class Elb
      def find_dns_and_zone_id elb_id
        elb = elb_driver.describe_load_balancers(:load_balancer_names => [elb_id])&.load_balancer_descriptions&.first
        { :canonical_hosted_zone_name_id => elb&.canonical_hosted_zone_name_id, :dns_name => elb&.dns_name }
      end

      def in_service_instance_ids elb_ids
        elb_ids.collect do |elb_id|
          elb_driver.describe_instance_health(load_balancer_name: elb_id).instance_states
            .collect{|instance| instance.state == 'InService' ? instance.instance_id : nil }.compact
        end.inject(:&)
      end

      private

      def elb_driver
        @elb_driver ||= Aws::ElasticLoadBalancing::Client.new
      end

    end
  end
end
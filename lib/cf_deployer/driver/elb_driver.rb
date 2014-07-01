module CfDeployer
  module Driver
    class Elb
      def find_dns_and_zone_id elb_id
        elb = elb_driver.load_balancers[elb_id]
        { :canonical_hosted_zone_name_id => elb.canonical_hosted_zone_name_id, :dns_name => elb.dns_name }
      end

      private

      def elb_driver
        AWS::ELB.new
      end

    end
  end
end
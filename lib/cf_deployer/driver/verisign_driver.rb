##  To use this driver instead of Route53 (the default), use the setting 'dns-driver'

module CfDeployer
  module Driver
    class Verisign

      def find_alias_target dns_zone, dns_fqdn
        raise "Not Implemented"
      end

      def set_alias_target dns_zone, dns_fqdn, elb_hosted_zone_id, elb_dnsname
        raise "Not Implemented"

        CfDeployer::Driver::DryRun.guard "Skipping Verisign DNS update" do
          # do update here
        end
      end

    end
  end
end
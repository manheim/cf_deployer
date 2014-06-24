module CfDeployer
  module Driver
    class Route53
      def initialize(aws_route53 = nil)
        @aws_route53 = aws_route53 || AWS::Route53.new
      end

      def find_alias_target(target_zone_name, target_host_name)
        target_zone = @aws_route53.hosted_zones.find { |z| z.name == trailing_dot(target_zone_name.downcase) }
        raise ApplicationError.new('Target zone not found!') if target_zone.nil?

        target_host = target_zone.resource_record_sets.find { |r| r.name == trailing_dot(target_host_name.downcase) }
        return nil if target_host.nil? || target_host.alias_target.nil?

        remove_trailing_dot(target_host.alias_target[:dns_name])
      end

      def set_alias_target(target_zone_name, target_host_name, elb_hosted_zone_id, elb_dnsname)
        Log.info "set alias target --Hosted Zone: #{target_zone_name} --Host Name: #{target_host_name} --ELB DNS Name: #{elb_dnsname} --ELB Zone ID: #{elb_hosted_zone_id}"
        target_zone_name = trailing_dot(target_zone_name)
        target_host_name = trailing_dot(target_host_name)
        target_zone = @aws_route53.hosted_zones.find { |z| z.name == target_zone_name }
        raise ApplicationError.new('Target zone not found!') if target_zone.nil?

        change = {
          action: "UPSERT",
          resource_record_set: {
            name: target_host_name,
            type: "A",
            alias_target: {
              dns_name: elb_dnsname,
              hosted_zone_id: elb_hosted_zone_id,
              evaluate_target_health: false
            }
          }
        }

        batch = {
          hosted_zone_id: target_zone.path,
          change_batch: {
            changes: [change]
          }
        }

        CfDeployer::Driver::DryRun.guard "Skipping Route53 DNS update" do
          change_resource_record_sets_with_retry(batch)
        end
      end

      private

      def change_resource_record_sets_with_retry(batch)
        attempts = 0
        while attempts < 20
          begin
            attempts = attempts + 1
            @aws_route53.client.change_resource_record_sets(batch)
            return
          rescue Exception => e
            Log.info "Failed to update alias target, trying again in 20 seconds."
            sleep(20)
          end
        end

        raise ApplicationError.new('Failed to update Route53 alias target record!')
      end

      def trailing_dot(text)
        return text if text[-1] == '.'
        "#{text}."
      end

      def remove_trailing_dot(text)
        return text[0..-2] if text && text[-1] == '.'
        text
      end
    end
  end
end

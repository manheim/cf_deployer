module CfDeployer
  module DeploymentStrategy
    class CnameSwap < BlueGreen

      def deploy
        Log.info "Found active stack #{active_stack.name}" if active_stack
        delete_stack inactive_stack
        create_inactive_stack
        warm_up_inactive_stack
        swap_cname
        Kernel.sleep 60
        run_hook(:'after-swap')
        Log.info "Active stack has been set to #{inactive_stack.name}"
        delete_stack(active_stack) if active_stack && !settings[:'keep-previous-stack']
        Log.info "#{component_name} deployed successfully"
      end


      def kill_inactive
        raise ApplicationError.new("Stack: #{inactive_stack.name} does not exist, cannot kill it.") unless inactive_stack.exists?
        delete_stack inactive_stack
      end

      def switch
        raise ApplicationError.new('There is only one color stack active, you cannot switch back to a non-existent version') unless both_stacks_exist?
        swap_cname
        Log.info "Active stack has been set to #{inactive_stack.name}"
        Log.info "#{component_name} switched successfully"
      end

      def destroy_post
        dns_driver.delete_record_set(dns_zone, dns_fqdn) 
      end

      private


      def active_cname
        @active_cname ||= get_active_cname
      end



      def create_inactive_stack
        inactive_stack.deploy
        get_parameters_outputs(inactive_stack)
        run_hook(:'after-create')
      end

      def swap_cname
        set_cname_to(inactive_stack)
      end

      def set_cname_to(stack)
        cname, zone_id =  find_elb_cname_for_stack(stack, elb_output_key)
        dns_driver.set_alias_target(dns_zone, dns_fqdn, zone_id, cname)
      end


      def stack_active?(stack)
        return false unless stack.exists?
        return false unless active_cname.length > 0
        cname, zone_id = find_elb_cname_for_stack(stack, elb_output_key)
        active_cname.downcase == cname.downcase
      end


      def get_active_cname
        dns_driver.find_alias_target(dns_zone, dns_fqdn) || ""
      end


      def elb_output_key
        settings[:'elb-name-output']
      end

      def dns_fqdn
        settings[:'dns-fqdn']
      end

      def dns_zone
        settings[:'dns-zone']
      end

      def dns_driver
        context[:dns_driver] || string_to_class(settings[:'dns-driver'])
      end

      def elb_driver
        context[:elb_driver] || CfDeployer::Driver::Elb.new
      end

      def settings
        context[:settings]
      end

      def find_elb_cname_for_stack(stack, elb_name_output_key)
        return ['', ''] unless stack.exists?
        elb_id = stack.output(elb_name_output_key)
        attrs = elb_driver.find_dns_and_zone_id(elb_id)
        [attrs[:dns_name] || '', attrs[:canonical_hosted_zone_name_id] || '']
      end

      def string_to_class class_string
        class_string.split('::').inject(Object) do |mod, class_name|
          mod.const_get(class_name)
        end.new
      end

    end
  end
end

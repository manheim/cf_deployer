module CfDeployer
  module Driver
    class Instance

      GOOD_STATUSES = [ :running, :pending ]

      def initialize instance_obj_or_id
        if instance_obj_or_id.is_a?(String)
          @id = instance_obj_or_id
        else
          @instance_obj = instance_obj_or_id
        end
      end

      def status
        instance_info = { }
        [:public_ip_address, :private_ip_address, :image_id].each do |stat|
          instance_info[stat] = aws_instance.send(stat)
        end
        instance_info[:status] = aws_instance.state
        instance_info[:key_pair] = aws_instance.key_pair.name
        instance_info
      end

      def aws_instance
        @instance_obj ||= Aws::EC2::Instance.new(@id)
      end
    end
  end
end
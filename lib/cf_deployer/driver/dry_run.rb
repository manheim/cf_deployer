module CfDeployer
  module Driver
    class DryRun

      @@enabled = false

      def self.enabled?
        @@enabled
      end

      def self.run_with_value value, &block
        previous_value = @@enabled
        @@enabled = value
        begin
          block.call
        rescue => e
          raise e
        ensure
          @@enabled = previous_value
        end
      end

      def self.enable_for &block
        run_with_value(true, &block)
      end

      def self.disable_for &block
        run_with_value(false, &block)
      end

      def self.enable
        CfDeployer::Log.info "Enabling Dry-Run Mode"
        @@enabled = true
      end

      def self.disable
        CfDeployer::Log.info "Disabling Dry-Run Mode"
        @@enabled = false
      end

      def self.guard description
        if @@enabled
          CfDeployer::Log.info "<Dry Run Enabled>  #{description}"
        else
          yield
        end
      end

    end
  end
end
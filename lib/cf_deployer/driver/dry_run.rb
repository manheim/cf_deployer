module CfDeployer
  module Driver
    class DryRun

      @@enabled = false

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
require 'spec_helper'

ARGV.clear

def asg_ids(*ids)
  values = Hash[ids.zip([nil] * ids.length)]
  {
      asg_instances: values
  }
end
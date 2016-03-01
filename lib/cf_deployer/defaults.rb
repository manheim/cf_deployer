module CfDeployer
  module Defaults
    ELBName = 'ELBName'
    AutoScalingGroupName = 'AutoScalingGroupName'
    Timeout = 1800
    DNSDriver = 'CfDeployer::Driver::Route53'
    RaiseErrorForUnusedInputs = false
    KeepPreviousStack = true
    CreateStackPolicyFileName = nil
    OverrideStackPolicyFileName = nil
    OverrideStackPolicy = false
  end
end

version 1.2.4:
  - Changed the default behavior of Blue/Green deployment strategy to keep previous stack after a new deployment.
  Now the previous deployed stack will be not deleted unless you set keep-previous-stack to false.

version 1.2.5:
  - Throw errors when options cannot be recognised in cf_deployer.yml in order to help users to find configure errors early.
  - Added setting raise-error-for-unused-inputs in cf_deployer.yml, which is false by default. When this setting is set to true, errors will be thrown if any inputs defined in cf_deployer.yml or given via command line -i parameters have no co-responding parameters in CloudFormation json templates.

version 1.2.6
  - Fixed broken command status and -d (dry-run) options.

version 1.2.7
  - Fixed broken option 'capabilities' under components.

version 1.2.8
  - Removed configure option validion at root level. Now users can have their own options at the root level in cf_deployer.yml file.

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

version 1.2.9
  - Support notify option in cf_deployer.yml, which can be set to ARNs of AWS topics to get notification of events of cloud-formation stacks.

version 1.2.10
  - Update DETAILS.md

version 1.2.11
  - Remove record set in R53 when stacks are deployed

version 1.3.1
  - Adding way to run hooks manually (outside of deploy)
  - Adding new command 'diff' to allow diffing between the deployed JSON
  - Split after-create and after-update hooks for create-or-update strategy

version 1.3.2
  - Display details of error message when referenced components do not exist

version 1.3.3
  - increase default timeout from 900 to 1800

version 1.3.6
  - explicitly enforce aws-sdk v.1.44.0 as a dependency

version 1.3.7
  - Increased the number of AWS-SDK retries
  - Added missing after-update hook to config validation
  - Added rescue around healthy_instance_count, to prevent intermittent failures from stopping deployment

version 1.3.8
  - Moved dependencies out of Gemfile and into gemspec
  - Removed Gemfile.lock

version 1.3.9
  - Allow new ASGs to be added to template (See: https://github.com/manheim/cf_deployer/issues/31)

version 1.4.0
  - Merge settings from parent component when given (https://github.com/manheim/cf_deployer/pull/37)
  - Added support for stack policies (https://github.com/manheim/cf_deployer/pull/40)
  - Fix broken Travis builds with newer version of bundler (https://github.com/manheim/cf_deployer/pull/42)

version 1.5.0
  - Treat deployments that end in a rollback as a failure

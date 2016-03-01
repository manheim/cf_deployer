##### [README](README.md) - [QUICKSTART](QUICKSTART.md) - [DETAILS](DETAILS.md) - [FAQ](FAQ.md)

CFDeployer - Usage Details
==============

```shell
Commands:
  cf_deploy config [ENVIRONMENT]                     # Show parsed config
  cf_deploy deploy [ENVIRONMENT] [COMPONENT]         # Deploy the specified components
  cf_deploy destroy [ENVIRONMENT] [COMPONENT]        # Destroy the specified environment/component
  cf_deploy help [COMMAND]                           # Describe available commands or one specific command
  cf_deploy json [ENVIRONMENT] [COMPONENT]           # Show parsed CloudFormation JSON for the target component
  cf_deploy kill_inactive [ENVIRONMENT] [COMPONENT]  # Destroy the inactive stack for a given component/environment
  cf_deploy status [ENVIRONMENT] [COMPONENT]         # Show the status of the specified Cloud Formation components specified in your yml
  cf_deploy switch [ENVIRONMENT] [COMPONENT]         # Switch active and inactive stacks

Options:
  -f, [--config-file=CONFIG-FILE]  # cf_deployer config file
                                   # Default: config/cf_deployer.yml
  -l, [--log-level=LOG-LEVEL]      # logging level
                                   # Default: info
                                   # Possible values: info, debug, aws-debug
  -d, [--dry-run]                  # Say what we would do but don't actually make changes to anything
  -s, [--settings=key:value]       # key:value pair to overwrite setting in config
  -i, [--inputs=key:value]         # key:value pair to overwrite in template inputs
  -r, [--region=REGION]            # Amazon region
                                   # Default: us-east-1

```

================
#### Defaults

By default cf_deployer looks at the config/cf_deployer.yml
 * This can be overridden by using the -f flag
```shell
cf_deployer -f samples/my_config.yml
```

By default cf_deployer will try and deploy all components listed in
your config file

When using Cname Swap it looks for the ELB Name as an output referenced
by the key 'ELBName'
When using Auto Scaling Group Swap it looks for the Auto Scaling Group
name as an output referenced by the key 'AutoScalingGroupName'

Default user hook timeout is 10 minutes, this can be overridden as shown
in the examples below

For Blue/Green deployments keep-previous-stack is defaulted to true.
This means that after a deployment, the previous deployed stack will be kept.
For non-production environment, you may set it to false to delete the previous stack
after a deployment for saving cost.

If the CloudFormation template has the output named 'AutoScalingGroupName'
or the cf_deployer.yml has the setting 'auto-scaling-group-name-output',
CfDeployer knows that auto-scaling groups need to deploy and will warm up
the auto-scaling groups by checking associated ELB instance status if applicable.

===================
### Deployment Strategies

There are 3 strategies for deploying with cf_deployer:
* create_or_update
  * **Non-Blue-Green** - Updates the CloudFormation directly
* cname_swap
  * **Blue-Green** - Deploy to the inactive stack, then swap the CNAME entry to point to the
    ElbName output from your CloudFormation template.
* auto_scaling_group_swap
  * **Blue-Green** - Deploy to the inactive stack, then warm up the new auto scaling
    group to the same size as old. Then cool down (set instances to 0) the old auto scaling group.

==================
### Settings vs Inputs

##### Settings:
Used by the gem for blue/green deployments and naming conventions

  * **For all deploys - These are the settings you can use**
    * dns-driver (defaults to CfDeployer::Driver::Route53)
    * keep-previous-stack (True/False: for Cname-Swap and Auto Scaling Group Swap, previous stack will be kept after new stack is created by default. Set it to false to delete the previous stack)
    * raise-error-for-unused-inputs (True/False: it is false by default. If it is set to true, errors will be thrown if there are any inputs which are not used as parameters of CloudFormation json templates. If it is set to false or the setting does not exist, warnings will be printed in the console if there are un-used inputs.)
    * auto-scaling-group-name-output
    * create-stack-policy-filename: the name of the json file (w/o the json
      extension) holding the stack policy to be used during the creation of the
      component stack.  the file is assumed to be relative to the config
      directory.
    * override-stack-policy-filename: the name of the json file (w/o the json
      extension) holding the stack policy to be used during updates of component
      stacks when the `override-stack-policy` setting is true. the file is
      assumed to be relative to the config directory.
    * override-stack-policy: (true/false) whether to use the override policy
* **For Components Using the Cname-Swap Deployment Strategy**
    * dns-fqdn (DNS record set name, for example, myApp.api.abc.com)
    * dns-zone (DNS hosted zone, for example, api.abc.com)
    * elb-name-output

##### Inputs:
Used by CloudFormation in the JSON template (Note: Settings can be used as inputs, but inputs are not used as settings).  These can be almost anything.  They are defined in the **Parameters** block in the CF template.



=================
### Tagging Your Stacks

You can use tags option to tag your application. The root level tags will be applied to all the components.
The component level tags will be only applied to that component. When a component with tags is deploying, the co-responding cloud-formation stack and auto-scaling groups and ec2 instances within the stack will be tagged with the tags of the component.

```
tags:
  project: my-project
  environment: <%= environment %>
  ownerEmail: awesome@domain.com
components:
  web:
    capabilities:
      - CAPABILITY_IAM
    tags:
      component: web

```

=================
### Get notification of events of cloud-formation stacks

You can create ASW SNS topics and set the notify option to the ARNs of the topics to get notification of the events of cloud-formation stacks.
The notify option can be set to a string or an array of strings.

```
notify: arn:foo:boo:mytopic
components:
  web:
    notify: arn:web:topic
environments:
  prod:
    notify: arn:only-prod:topic

```
==================
### How Termination Works

Blue/Green deployments keep at most 2 different stacks up (Blue and
  Green).  If both are deployed and Green is active, Blue will be deleted
before being deployed with the newest version.

Components may be deleted several different ways:

* By default with Blue/Green deployments, after deploying a color (Green)
  stack, the opposite color (Blue) will be kept.
  * This can be overridden with the keep-previous-stack setting set as
    false.
* You can use the destroy command and it will delete any versions
  (blue/green) of the specified component that exist (BE CAREFUL!!)
* You can use the kill_inactive command to delete the 'inactive stack'
  * For cname-swap this is the stack that DNS is _not_ pointing to
  * For asg_swap this is the stack that has an autoscaling group with 0
    instances


==============
### Hooks

There are 3 places currently where a user-provided script can be run
before continuing with the deploy process. (Specified in the cf_deployer.yml)  Information about how to add new hooks is at the bottom of this document.

* **before-destroy**
  * This runs before a stack is spun down (This happens on delete, as
    well as when spinning down the stack so a new version may be
deployed)
* **after-create**
  * CnameSwap: Before the cname is switched to the new version (Smoke
    Test)
  * AutoScalingGroupSwap: Before warming up the new stack and cooling
    down the old
* **after-swap**
  * CnameSwap: After the cname is switched (Wait Script to ensure DNS
    Switch happened)
  * AutoScalingGroupSwap: After the warming up the new stack, and
    cooling down the old stack

#### Examples:

##### Ruby Code:
    components:
      web:
        after-create: raise 'Server is down' unless system('curl -f http://mydomain.com/status')

##### Ruby Code with Timeout:
    components:
      web:
        after-create:
          code: raise 'Server is down' unless system('curl -f http://mydomain.com/status')
          timeout: 1500

##### Ruby Code in a Separate File:
    components:
      web:
        after-create:
          file: smoke_test.rb



================
### ERB Like a Pro

CFDeployer runs its YAML config file and all CF JSON templates through ERB to allow sophisticated templating.

#### ERB in cf_deployer.yml

##### ERB Templating in your cf_deployer.yml:
```
<% app_name = 'my_app' %>

application: <%= app_name %>

settings:
  inputs:
    S3BucketName: <%= app_name %>-<%= environment %>-artifacts
```
* Note that  'environment' is exposed to the template.  Other settings and inputs are not available yet because the parsing hasn't happened yet.


##### This also allows the use of helper classes to abstract organization-specific boilerplate settings:
```
<%
require 'my_cfd_helper'
helper = MyCfdHelper::SettingsHelper.new
%>

settings:
  inputs:
    InstanceSubnets: <%= helper.instance_subnets %>
    SecurityGrouops: <%= helper.default_security_groups %>
    ElasticIP:       <%= helper.next_available_elastic_ip %>
```


#### ERB in component_cf.json

##### Similarly to the cf_deployer.yml example above, ERB can be used with a helper class to abstract boilerplate JSON.  This example might be used stand up a basic, ElasticBeanstalk-like web stack:

```
<%
require 'my_cfd_helper'
helper = MyCfdHelper::TemplateHelper.new config
component_name  = config[:settings][:component].capitalize
%>
{
  "AWSTemplateFormatVersion": "2010-09-09",
  "Description": "<%= config[:settings][:application] %> Web Stack",
  "Parameters": {
     <%= template_helper.standard_params %>
    ,<%= template_helper.asg_params %>
    ,<%= template_helper.elb_params %>
  },
  "Resources": {
     <%= template_helper.component_role :component_name => component_name %>
    ,<%= template_helper.web_elb :component_name => component_name %>
    ,<%= template_helper.asg :component_name => component_name,
                             :elb_name => "#{component_name}ServerELB",
     %>
  },
  "Outputs": {
     <%= template_helper.asg_outputs :component_name => component_name %>
    ,<%= template_helper.elb_outputs :component_name => component_name %>
  }
}

```
* Note that the component-specific settings and inputs parsed from the cf_deployer.yml are made available via the 'config' Hash.
DNS Providers are pluggable based on the dns-driver setting.  To supply a new driver, you'll need to implement the find_alias_target and set_alias_target methods. See lib/cf_deployer/dns/ for examples.


================
### Extending CFDeployer

#### Adding New Hooks

Hooks should be relatively simple to extend.  The Hook class should be initialized with the hook information pulled from the config file,
not hard-coded ruby.  Convention is the YAML contains a key with the
name of the hook as the key.  The value can be:
* Ruby Code
* A hash containing the :file key (Takes a file relative to the config
  file directory)
* A hash containing the :code key

The instantiated object can then be #run This takes any one parameter (generally a hash, currently a hash with all your settings/inputs/JSON Template information) which
will then be available in the user defined script/code (Currently the
hash may be referenced by accessing the 'context' variable that is
available due to passing the binding to eval in CfDeployer::Hook#execute)

#### Adding New DNS Providers

DNS Providers are pluggable based on the dns-driver setting.  To supply a new driver, you'll need to implement the find_alias_target and set_alias_target methods. See lib/cf_deployer/driver/ for examples.

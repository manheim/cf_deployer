[![Code Climate](https://codeclimate.com/github/manheim/cf_deployer/badges/gpa.svg)](https://codeclimate.com/github/manheim/cf_deployer)

##### [README](README.md) - [QUICKSTART](QUICKSTART.md) - [DETAILS](DETAILS.md) - [FAQ](FAQ.md)

CFDeployer
================

## Installing

```
$ gem install cf_deployer
```

## Basic Help

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

##### [README](README.md) - [QUICKSTART](QUICKSTART.md) - [DETAILS](DETAILS.md) - [FAQ](FAQ.md)

CFDeployer - Quickstart
======================

### To start using CFDeployer with your project, you need:

* A working CloudFormation JSON template that is able to deploy a working instance of your application

* A cf_deployer.yml file that describes the components of your application and how they are deployed

This Quickstart will use the files in our [simple sample](samples/simple)

==================
### CloudFormation Templates

JSON-based CF templates are how you describe to CloudFormation what AWS resources to deploy and how they are configured.  There are lots of good resources out there that explain how to write CF templates.  CF templates can get pretty complex, depending on what AWS resources your application needs and writing the templates themselves is outside the scope of this documentation.  Some good information about CF templates can be found here:

* The official [AWS CloudFormation](http://aws.amazon.com/cloudformation/) page

* [Getting Started with AWS CloudFormation](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/GettingStarted.html)

* [Anatomy of an AWS CloudFormation template](http://www.techrepublic.com/blog/the-enterprise-cloud/anatomy-of-an-aws-cloudformation-template/6117/)

* [Bootstrapping Applications via AWS CloudFormation](https://s3.amazonaws.com/cloudformation-examples/BoostrappingApplicationsWithAWSCloudFormation.pdf)

* [Create Your AWS Stack From a Recipe](http://aws.typepad.com/aws/2011/02/cloudformation-create-your-aws-stack-from-a-recipe.html)

* [Basic examples included with CFDeployer](samples/)

* The **ERB Like a Pro** section of our [DETAILS](DETAILS.md) page can show you some techniques for pulling some boilerplate out of your CF templates.

Note that you can use ERB and settings/inputs from the cf_deployer.yml file while developing your CloudFormation template by using CFD's **json** command and piping the output to a static CF template file.  The static file can then be fed to CF via the AWS console or commandline utilities.  Once you have a working CloudFormation template, you're ready to get started with CFDeployer.


==================
### Setting up your project to use CFDeployer

* **CFDeployer is a Ruby gem so you'll need a working version of Ruby.**  CFDeployer should work with any 1.8.7 or 1.9.X Ruby interpreter.  CFDeployer uses the official AWS-published Ruby SDK under the covers which, in turn, uses Nokogiri.  We've heard that JRuby projects and Ruby 2.X projects have trouble getting Nokogiri installed so that might be an issue for your if you're using one of those Rubies.

* **The use of the [Bundler](http://bundler.io/) gem is strongly encouraged.**  Put "gem 'cf_deployer'" into your Gemfile.

* **Tell Bundler to install CFDeployer and its dependencies**
```shell
bundle install
```

* **Make a 'config' directory to store your CloudFormation template and cf_deployer.yml files in.**  The cf_deployer.yml file is assumed to be in the same directory as your CF templates.  The path to your cf_deployer.yml can be specified with the --config-file (-f) commandline option.
```shell
mkdir config
```

* **Put your CF templates and cf_deployer.yml file into the config directory**


==================
### Using CFDeployer

The examples shown are specifying the 'qa' environment.  Our cf_deployer.yml doesn't specify any particular settings or inputs for that environment so CFD uses the defaults from the YAML file, just like it would for any other ad hoc environment.

**Showing the parsed and ERBed settings that CFDeployer will use:**
```shell
bundle exec cf_deploy config qa
```

**Showing the parsed and ERBed CloudFormation template for the 'web' component:**
```shell
bundle exec cf_deploy json qa web
```

**Deploying a component:**
```shell
bundle exec cf_deploy deploy qa web
```

**Showing what CloudFormation stacks exist for an environment/component:**
```shell
bundle exec cf_deploy status qa
```

**Deploying a new version of your application in a blue/green fashion:**
```shell
bundle exec cf_deploy deploy qa web
```
Note that CFD will shut down the inactive stack, if it exists.  The new stack will then be made active and the old stack will be made inactive (or terminated, depending on your cf_deployer.yml settings).

**Destroying all stacks for one component in an environment:**
```shell
bundle exec cf_deploy destroy qa web
```

**Destroying all stacks for ALL components in an environment:**
```shell
bundle exec cf_deploy destroy qa
```


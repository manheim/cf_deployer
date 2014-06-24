##### [README](README.md) - [QUICKSTART](QUICKSTART.md) - [DETAILS](DETAILS.md) - [FAQ](FAQ.md)

CFDeployer - FAQ
=======================================

**CFDeployer is *GREAT*!  How did you come up with the idea to write it?**

We shamelessly stole the original idea from the smart guys at ThoughtWorks Studios who created a gem called [EB Deployer](http://getmingle.io/eb_deployer/) for doing easy, blue/green deployments with ElasticBeanstalk.  Thanks for the great work, guys!

==========

**If EbD is so great, why bother creating CFD?**

EbD **IS** great but it only supports ElasticBeanstalk.  EB is fine for pretty simple applications, but if you're writing something complex, with multiple components (including some that aren't web services and don't use ELBs), then it's not really a great fit.  CloudFormation gives you a lot more flexibility and power (which is why EB uses it under the covers) but there wasn't an easy way to do blue/green deployments with it.

==========

**Ok, so how is CFD different?**

* For starters, CFD **only** supports CloudFormation-based deployments, **not** ElasticBeanstalk.  If you want to use EB, just use EB Deployer.

* CFD understands the concept that an application is often made up of multiple *components* that are deployed separately but are logically part of the same application.

* CFD allows your to add business-specific tags to your CF stacks

* CFD has a few options for user defined hook scripts: before-destroy, after-create, after-swap.  Which allows for more flexibility. (ie. Before destroying an S3 bucket, the user will need to empty it.)

* Support for multiple deployment strategies: create-update, cname-swap (Blue/Green), auto-scaling-group-swap (Blue/Green)

* CFD will pass your YAML file and CloudFormation JSON template through ERB to allow for more flexibility

===========

**So what parts of my application would be separate components?**

Because CloudFormation allows you to deploy complex things like a stack with multiple AutoScalingGroups, for example, it can be a little hard to decide what parts of your application should be considered different components for CFD.  Generally, the question that really matters is, "What parts of my application must be deployed at the same time?"  If you want to be able to deploy your web service independently of your back-end data processing worker, you probably want them to be two different CFD components.

===========

**My *cf_deployer.yml* file is awfully repetitive.  How can I DRY that up?**

Aside from using the usual YAML techniques to reuse common stuff, we pass the **cf_deployer.yml** file through Ruby's built-in templating system, ERB, to process inline Ruby code.  With ERB, you could do all kinds of things to clean up that file like pulling parts of it into other files or dynamically generating common values.  More info about ERB can found [here](http://www.stuartellis.eu/articles/erb/) and [here](http://www.startuprocket.com/blog/a-quick-introduction-to-embedded-ruby-erb-eruby).

===========

**My *CloudFormation JSON templates* are REALLY long.  What can I do about that?**

The JSON templates are run through ERB too so you can do lots of things.  Here at [Manheim](http://www.manheim.com), we wrote a CFD Helper gem to help pull all of the boilerplate JSON out of our individual projects.  See the [DETAILS](DETAILS.md) page for an example of what this can look like.

===========

**How can I contribute to CFD?**

First off, thanks for wanting to help out!

0. Fork it on GitHub
0. Create your feature branch:  `git checkout -b my-new-feature`
0. Make your changes
0. Commit your changes:  `git commit -am 'Added some feature'`
0. Push the branch to GitHub:  `git push origin my-new-feature`
0. Create a new Pull Request on GitHub
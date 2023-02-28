require 'spec_helper'
describe "load config settings" do

  before :each do
    Dir.mkdir 'tmp' unless Dir.exists?('tmp')
    @config_file = File.expand_path("../../../tmp/test_config.yml", __FILE__)
    @base_json = File.expand_path("../../../tmp/base.json", __FILE__)
    @api_json = File.expand_path("../../../tmp/api.json", __FILE__)
    @front_end_json = File.expand_path("../../../tmp/front-end.json", __FILE__)
    @very_simple_json = File.expand_path("../../../tmp/very-simple.json", __FILE__)
    @json_with_erb = File.expand_path("../../../tmp/json-with-erb.json", __FILE__)
    @broken_json = File.expand_path("../../../tmp/broken_json.json", __FILE__)
    @broken_erb = File.expand_path("../../../tmp/broken_erb.json", __FILE__)

    base_json = <<-eos
    {
      "Parameters" : {},
      "Outputs" : {
        "vpc-id" : {},
        "AutoScalingGroupName" : {},
        "public-subnet-id" : {}
      }
    }
    eos

    json_with_erb = <<-eos
    {
      "Description": "<%= config[:inputs][:environment] %>"
    }
    eos

    very_simple_json = <<-eos
    {
      "Parameters" : {},
      "Outputs" : {
        "vpc-id" : {},
        "public-subnet-id" : {}
      }
    }
    eos

    api_json = <<-eos
    {
      "Parameters" : {
        "require-basic-auth" : { "Default" : "true" }
      }
    }
    eos

    front_end_json = <<-eos
    {
      "Parameters" : {
        "require-basic-auth" : {},
        "mail-server" : {}
      },
      "Outputs" : {
        "AutoScalingGroupName" : {},
        "elb-cname" : {}
      }
    }
    eos

    broken_json = '{ "Some_broken_json": "foo" '
    broken_erb  = '{ "Some_broken_erb": "<%= [1, 2, 3].first("two") %>" }'
    @broken_yaml = "something: [ :foo "

    File.open(@api_json,         'w') {|f| f.write(api_json) }
    File.open(@base_json,        'w') {|f| f.write(base_json) }
    File.open(@front_end_json,   'w') {|f| f.write(front_end_json) }
    File.open(@very_simple_json, 'w') {|f| f.write(very_simple_json) }
    File.open(@json_with_erb,    'w') {|f| f.write(json_with_erb) }
    File.open(@broken_json,      'w') {|f| f.write(broken_json) }
    File.open(@broken_erb,       'w') {|f| f.write(broken_erb) }


    yaml_string = <<-eos
application: myApp
components:
  base:
    deployment-strategy: create-or-update
    tags:
      component: base
    inputs:
      foobar: <%= environment %>.IsGreat
    notify:
      - arn:base
  api:
    deployment-strategy: auto-scaling-group-swap
    depends-on:
      - base
    inputs:
      require-basic-auth: true
      timeout: 90
      mail-server: http://api.abc.com
    notify: arn:api
  front-end:
    deployment-strategy: cname-swap
    notify: arn:base
    depends-on:
      - base
      - api
    inputs:
      cname: front-end.myserver.com
    settings:
      keep-previous-stack: false
  very-simple:
  json-with-erb:
  #broken-json:
  #broken_erb:

inputs:
  require-basic-auth: false
  timeout: 300
  mail-server: http://abc.com
  cname: myserver.com

notify:
  - arn:root

tags:
  version: v1.1

environments:
  dev:
    inputs:
      mail-server: http://dev.abc.com
      timeout: 60
    notify: arn:dev
  production:
    inputs:
      requires-basic-auth: true
      mail-server: http://prod.abc.com
    components:
      front-end:
        inputs:
          cname: prod-front-end.myserver.com
    eos
    File.open(@config_file, 'w') {|f| f.write(yaml_string) }

  end

  before :each do
     ENV['timeout'] = nil
     ENV['cfdeploy_settings_timeout'] = nil
  end

  it "all the keys should be symbols in config" do
    config =  CfDeployer::ConfigLoader.new.load({:'config-file' => @config_file})
    expect(config[:components][:base][:'deployment-strategy']).to eq('create-or-update')
    expect(config['components']).to be_nil
  end

  it "should copy application, environment, component to component settings" do
    config =  CfDeployer::ConfigLoader.new.load({:'config-file' => @config_file, :environment => 'uat'})
    expect(config[:components][:api][:settings][:application]).to eq("myApp")
    expect(config[:components][:api][:settings][:component]).to eq("api")
    expect(config[:components][:api][:settings][:environment]).to eq("uat")
    expect(config[:components][:base][:settings][:application]).to eq("myApp")
    expect(config[:components][:base][:settings][:component]).to eq("base")
    expect(config[:components][:base][:settings][:environment]).to eq("uat")
  end

  it "should copy region to coponent settings" do
    config =  CfDeployer::ConfigLoader.new.load({:'config-file' => @config_file, :environment => 'uat', :region => 'us-west-1'})
    expect(config[:components][:api][:settings][:region]).to eq("us-west-1")
    expect(config[:components][:base][:settings][:region]).to eq("us-west-1")
  end

  it "should copy application, environment, component to component inputs" do
      config =  CfDeployer::ConfigLoader.new.load({:'config-file' => @config_file, :environment => 'uat'})
      expect(config[:components][:api][:inputs][:application]).to eq("myApp")
      expect(config[:components][:api][:inputs][:component]).to eq("api")
      expect(config[:components][:api][:inputs][:environment]).to eq("uat")
      expect(config[:components][:base][:inputs][:application]).to eq("myApp")
      expect(config[:components][:base][:inputs][:component]).to eq("base")
      expect(config[:components][:base][:inputs][:environment]).to eq("uat")
  end

  it "should copy region to coponent inputs" do
    config =  CfDeployer::ConfigLoader.new.load({:'config-file' => @config_file, :environment => 'uat', :region => 'us-west-1'})
    expect(config[:components][:api][:inputs][:region]).to eq("us-west-1")
    expect(config[:components][:base][:inputs][:region]).to eq("us-west-1")
  end

  it "config_dir option should be copied to component context" do
    config_dir = File.dirname(@config_file)
    config =  CfDeployer::ConfigLoader.new.load({:'config-file' => @config_file, :environment => 'uat'})
    expect(config[:components][:api][:config_dir]).to eq(config_dir)
    expect(config[:components][:base][:config_dir]).to eq(config_dir)
    expect(config[:components][:'front-end'][:config_dir]).to eq(config_dir)
  end

  it "notify option should be merged to component context" do
    config =  CfDeployer::ConfigLoader.new.load({:'config-file' => @config_file, :environment => 'dev'})
    expect(config[:components][:base][:notify]).to eq(['arn:root', 'arn:base', 'arn:dev'])
    expect(config[:components][:api][:notify]).to eq(['arn:root', 'arn:api', 'arn:dev'])
    expect(config[:components][:'front-end'][:notify]).to eq(['arn:root', 'arn:base', 'arn:dev'])
  end

  it "notify option should be merged to environment context" do
    config =  CfDeployer::ConfigLoader.new.load({:'config-file' => @config_file, :environment => 'uat'})
    expect(config[:components][:base][:notify]).to eq(['arn:root', 'arn:base'])
    expect(config[:components][:api][:notify]).to eq(['arn:root', 'arn:api'])
    expect(config[:components][:'front-end'][:notify]).to eq(['arn:root', 'arn:base'])
  end

  it "tags option should be copied to component context" do
    config =  CfDeployer::ConfigLoader.new.load({:'config-file' => @config_file, :environment => 'uat'})
    expect(config[:components][:api][:tags]).to eq({:version => 'v1.1'})
    expect(config[:components][:base][:tags]).to eq({:version => 'v1.1', :component => 'base'})
    expect(config[:components][:'front-end'][:tags]).to eq({:version => 'v1.1'})
  end


  it "component's settings should be merged to common settings" do
    config =  CfDeployer::ConfigLoader.new.load({:'config-file' => @config_file, :environment => 'uat'})
    expect(config[:components][:api][:inputs][:'timeout']).to eq(90)
    expect(config[:components][:api][:inputs][:'require-basic-auth']).to eq(true)
    expect(config[:components][:api][:inputs][:'mail-server']).to eq('http://api.abc.com')
  end


   it "environment's settings should be merged to component settings" do
    config =  CfDeployer::ConfigLoader.new.load({:'config-file' => @config_file, :environment => 'dev'})
    expect(config[:components][:api][:inputs][:'timeout']).to eq(60)
    expect(config[:components][:api][:inputs][:'require-basic-auth']).to eq(true)
    expect(config[:components][:api][:inputs][:'mail-server']).to eq('http://dev.abc.com')
  end

  it "should merge environment's components to component settings" do
    config =  CfDeployer::ConfigLoader.new.load({:'config-file' => @config_file, :environment => 'production'})
    expect(config[:components][:'front-end'][:inputs][:'cname']).to eq('prod-front-end.myserver.com')
    expect(config[:components][:api][:inputs][:'cname']).to eq('myserver.com')
  end

  it "environment variables without prefix 'cfdeploy_settings_' should not be merged to components settings" do
    ENV['timeout'] = "180"
    config =  CfDeployer::ConfigLoader.new.load({:'config-file' => @config_file, :environment => 'dev'})
    expect(config[:components][:api][:inputs][:'timeout']).to eq(60)
  end

  it "should merge environment variables should be merged to components settings" do
    ENV['cfdeploy_inputs_timeout'] = "180"
    config =  CfDeployer::ConfigLoader.new.load({:'config-file' => @config_file, :environment => 'dev'})
    expect(config[:components][:api][:inputs][:'timeout']).to eq("180")
  end

  it "cli settings should be merged to components settings" do
    ENV['cfdeploy_settings_timeout'] = "180"
    config =  CfDeployer::ConfigLoader.new.load({:'config-file' => @config_file, :environment => 'dev',:cli_overrides => {:settings => {:timeout => 45}}})
    expect(config[:components][:api][:settings][:'timeout']).to eq(45)
  end

  it "should set cloudFormation parameter names into each component" do
    config =  CfDeployer::ConfigLoader.new.load({:'config-file' => @config_file})
    expect(config[:components][:base][:defined_parameters]).to eq({})
    expect(config[:components][:api][:defined_parameters]).to eq({:'require-basic-auth' => {:Default => "true"}})
    expect(config[:components][:'front-end'][:defined_parameters]).to eq({:'require-basic-auth' => {}, :'mail-server' => {}})
  end

  it "should set cloudFormation output names into each component" do
    config =  CfDeployer::ConfigLoader.new.load({:'config-file' => @config_file})
    expect(config[:components][:base][:defined_outputs]).to eq({:'vpc-id' => {}, :'AutoScalingGroupName'=>{}, :'public-subnet-id'=>{}})
    expect(config[:components][:api][:defined_outputs]).to eq({})
    expect(config[:components][:'front-end'][:defined_outputs]).to eq({:'AutoScalingGroupName'=>{}, :'elb-cname' => {}})
  end

  it "should remove common settings in order not to confuse us" do
    config =  CfDeployer::ConfigLoader.new.load({:'config-file' => @config_file})
    expect(config[:settings]).to be_nil
  end

  it "should set default elb-name-output for cname-swap strategy" do
    config =  CfDeployer::ConfigLoader.new.load({:'config-file' => @config_file})
    expect(config[:components][:'front-end'][:settings][:'elb-name-output']).to eq('ELBName')
  end

  it "should set default auto-scaling-group-name-output for cname-swap strategy" do
    config =  CfDeployer::ConfigLoader.new.load({:'config-file' => @config_file})
    expect(config[:components][:api][:settings][:'auto-scaling-group-name-output']).to eq([ CfDeployer::Defaults::AutoScalingGroupName ])
  end

  it "should set auto-scaling-group-name-output to default if auto-scaling-group-name exists in output for create-or-update strategy" do
    config =  CfDeployer::ConfigLoader.new.load({:'config-file' => @config_file})
    expect(config[:components][:base][:settings][:'auto-scaling-group-name-output']).to eq([ CfDeployer::Defaults::AutoScalingGroupName ])
  end

  it "should not set auto-scaling-group-name-output to default if auto-scaling-group-name does not exists in output for create-or-update strategy" do
    base_json = <<-eos
    {
      "Outputs" : {
      }
    }
    eos

    File.open(@base_json, 'w') {|f| f.write(base_json) }
    config =  CfDeployer::ConfigLoader.new.load({:'config-file' => @config_file})
    expect(config[:components][:'base'][:settings][:'auto-scaling-group-name-output']).to be_nil
  end

  it "should set auto-scaling-group-name-output to default if auto-scaling-group-name exists in output for cname-swap strategy" do
    config =  CfDeployer::ConfigLoader.new.load({:'config-file' => @config_file})
    expect(config[:components][:'front-end'][:settings][:'auto-scaling-group-name-output']).to eq([ CfDeployer::Defaults::AutoScalingGroupName ])
  end

  it "should set raise-error-for-unused-inputs to default" do
    config =  CfDeployer::ConfigLoader.new.load({:'config-file' => @config_file})
    expect(config[:components][:'front-end'][:settings][:'raise-error-for-unused-inputs']).to eq(CfDeployer::Defaults::RaiseErrorForUnusedInputs)
  end

  it "should not set auto-scaling-group-name-output to default if auto-scaling-group-name does not exists in output for cname-swap strategy" do
    front_end_json = <<-eos
    {
      "Outputs" : {
        "elb-cname" : {}
      }
    }
    eos

    File.open(@front_end_json, 'w') {|f| f.write(front_end_json) }
    config =  CfDeployer::ConfigLoader.new.load({:'config-file' => @config_file})
    expect(config[:components][:'front-end'][:settings][:'auto-scaling-group-name-output']).to be_nil
  end

  it "should ERB the config file and provide the environment in the binding" do
    config =  CfDeployer::ConfigLoader.new.load(:'config-file' => @config_file, :environment => 'DrWho')
    expect(config[:components][:base][:inputs][:'foobar']).to eq('DrWho.IsGreat')
  end

  it "should ERB the component JSON and make the parsed template available" do
    config =  CfDeployer::ConfigLoader.new.load(:'config-file' => @config_file, :environment => 'DrWho')
    expect(CfDeployer::ConfigLoader.erb_to_json('json-with-erb', config[:components][:'json-with-erb'])).to include('DrWho')
  end

  it 'should use error_document to show the broken document when parsing broken ERB' do
    config = { :config_dir => File.dirname(@config_file) }
    allow_any_instance_of(CfDeployer::ConfigLoader).to receive(:error_document)
    expect { CfDeployer::ConfigLoader.erb_to_json('broken_erb', config) }.to raise_error(TypeError)
  end

  it 'should use error_document to show the broken document when parsing broken json' do
    loader = CfDeployer::ConfigLoader.new
    config = loader.load(:'config-file' => @config_file, :environment => 'DrWho')
    config[:components]['broken_json'] = {
      :config_dir => config[:components][:base][:config_dir],
      :inputs => {},
      :defined_parameters => {},
      :defined_outputs => {}
    }
    allow_any_instance_of(CfDeployer::ConfigLoader).to receive(:error_document)

    expect { loader.send(:cf_template, 'broken_json') }.to raise_error(RuntimeError)
  end

  it 'should use error_document to show the broken document when parsing broken yaml' do
    allow_any_instance_of(CfDeployer::ConfigLoader).to receive(:error_document)
    expect { CfDeployer::ConfigLoader.new.send(:load_yaml, @broken_yaml) }.to raise_error(Psych::SyntaxError)
  end

  it 'should set default keep-previous-stack to true' do
    config =  CfDeployer::ConfigLoader.new.load(:'config-file' => @config_file)
    expect(config[:components][:api][:settings][:'keep-previous-stack']).to eq(CfDeployer::Defaults::KeepPreviousStack)
  end

  it 'should keep keep-previous-stack setting' do
    config =  CfDeployer::ConfigLoader.new.load(:'config-file' => @config_file)
    expect(config[:components][:'front-end'][:settings][:'keep-previous-stack']).to be_falsey
  end

  context 'targets' do

    it 'should use all components as targets if no targets are specified' do
    config =  CfDeployer::ConfigLoader.new.load(:'config-file' => @config_file)
    expect(config[:targets]).to eq(['base', 'api', 'front-end', 'very-simple', 'json-with-erb'])
    end

    it 'should keep targets if targets are specified' do
    config =  CfDeployer::ConfigLoader.new.load(:'config-file' => @config_file, :component => ['api', 'web'])
    expect(config[:targets]).to eq(['api', 'web'])
    end

  end

  context 'load CF template' do
    it "should be able to load CF template even though inputs have referencing value not resolved" do
    api_template = <<-eos
    {
      "Parameters" : {
        "db" : "<%= config[:inputs][:db]%>",
        "url" : "<%= config[:inputs][:url]%>"
      },
      "Outputs" : {}
    }
    eos
    File.open(@api_json, 'w') {|f| f.write(api_template) }

    base_template = <<-eos
    {
      "Outputs" : {
        "elb-cname" : {}
      }
    }
    eos
    File.open(@base_json, 'w') {|f| f.write(base_template) }

    config = <<-eos
application: myApp
components:
  base:
  api:
    depends-on:
      - base
    inputs:
      url: http://abc.com
      db:
        component: base
        output-key: elb-cname
    eos
    File.open(@config_file, 'w') {|f| f.write(config) }

    config =  CfDeployer::ConfigLoader.new.load({:'config-file' => @config_file})
    expect(config[:components][:'api'][:defined_parameters]).to eq({ db:'base::elb-cname', url:'http://abc.com'})
  end

  end
end

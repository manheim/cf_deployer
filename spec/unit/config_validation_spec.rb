require 'spec_helper'

describe "Config Validation" do

  it "should pass validation if there is no errors" do
    config = {
      :targets => ['web', 'api', 'scaler'],
      :application => 'ABC.com-myAppfoo',
      :verbosity => 'all',
      :'dry-run' => false,
      :'output-format' => 'human',
      :components =>{
        :base => {
          :inputs => {:time_out => 30, :mail_server =>'abc'},
          :defined_outputs => {:VPCID => {}},
          :defined_parameters => {:mail_server => {}, :time_out => {}}
        },
        :web => {
          :'deployment-strategy' => 'cname-swap',
          :config_dir => 'samples/simple',
          :'before-destroy'=> "puts 'destroying'",
          :capabilities => ['CAPABILITIES_IAM'],
          :'after-create' => {
            :file => "after_create_hook.rb",
            :timeout => 30
           },
          :'after-swap' => {
            :code => "puts 'done'",
            :timeout => 300
           },
          :settings => {
            :'dns-fqdn' => 'myweb.man.com',
            :'dns-zone' => 'man.com',
            :'elb-name-output' => 'ELBID',
           },
           :inputs => {
            :vpc_id => {
              :component => 'base',
              :'output-key' => 'VPCID'
            }
          },
          :defined_parameters => {:vpc_id => {}},
          :defined_outputs => {:ELBID => {}}
        },
        :api => {
          :'deployment-strategy' => 'cname-swap',
          :settings => {
            :'dns-fqdn' => 'myapi.man.com',
            :'dns-zone' => 'man.com',
            :'elb-name-output' => 'ELBName',
          },
          :defined_outputs => {:ELBName => {}}
        },
        :scaler => {
          :'deployment-strategy' => 'auto-scaling-group-swap',
          :settings => {
            :'auto-scaling-group-name-output' => ['ASGName']
          },
          :defined_outputs => {:ASGName => {}}
        }
      },
      :environment =>{
        :dev => {}
      }
      }
    expect{CfDeployer::ConfigValidation.new.validate(config)}.not_to raise_error
  end

  it "should get error if hook is not string, code or file" do
    config = {
      :targets => ['base'],
      :application => 'myApp',
      :components =>{
        :base => {
          :'deployment-strategy' => 'cname-swap',
          :'before-destroy' => {:ruby => "puts 'hi'"},
          :'after-create' => {:something => ""},
          :'after-swap' => {:foo => "boo"},
          :settings => {
            :'dns-fqdn' => 'myweb.man.com',
            :'dns-zone' => 'man.com',
            :'elb-name-output' => 'ELBID'
          },
          :defined_outputs => {:ELBID => {}}
        }
      }}
    expect{CfDeployer::ConfigValidation.new.validate(config)}.to raise_error(/Invalid hook 'before-destroy'/)
    expect{CfDeployer::ConfigValidation.new.validate(config)}.to raise_error(/Invalid hook 'after-create'/)
    expect{CfDeployer::ConfigValidation.new.validate(config)}.to raise_error(/Invalid hook 'after-swap'/)
  end

  it "should get error if hook points to a file which does not exist" do
    config = {
      :targets => ['base'],
      :application => 'myApp',
      :components =>{
        :base => {
          :config_dir => '../samples',
          :'before-destroy' => {
            :file => "something.rb"}
        }
      }}
    expect{CfDeployer::ConfigValidation.new.validate(config)}.to raise_error("File '../samples/something.rb' does not exist, which is required by hook 'before-destroy'")
  end

  it "should get error if any CF parameters do not have co-responding settings" do
    config = {
      :targets => ['base'],
      :application => 'myApp',
      :components =>{
        :base => {
          :defined_parameters => {:mail_server =>{}}
        }
      }}
    expect{CfDeployer::ConfigValidation.new.validate(config)}.to raise_error("No input setting 'mail_server' found for CF template parameter in component base")
  end

  it "should not get error if any CF parameters do not have co-responding settings and we tell CV not to validate inputs" do
    config = {
      :targets => ['base'],
      :application => 'myApp',
      :components =>{
        :base => {
          :defined_parameters => {:mail_server =>{}}
        }
      }}
    expect{CfDeployer::ConfigValidation.new.validate(config, false)}.not_to raise_error
  end

  it "should not get error if any CF parameters do not have co-responding settings but the component is not a target to deploy" do
    config = {
      :targets => ['vpn'],
      :application => 'myApp',
      :components =>{
        :vpn => {},
        :web => {
          :defined_parameters => {:mail_server =>{}}
        }
      }}
    expect{CfDeployer::ConfigValidation.new.validate(config)}.not_to raise_error
  end

  it "should not get error if any deployment options are not set for a component that is not a target to deploy" do
    config = {
      :targets => ['vpn'],
      :application => 'myApp',
      :components =>{
        :vpn => {},
        :web => {
          :'deployment-strategy' => 'cname-swap',
          :inputs => { :foo => 'dd' }
        }
      }}
    expect{CfDeployer::ConfigValidation.new.validate(config)}.not_to raise_error
  end

  it "should not get error if CF parameters have a default and are not set in the config" do
    config = {
      :targets => ['base'],
      :application => 'myApp',
      :components =>{
        :base => {
          :defined_parameters => {:mail_server =>{:Default => 'abc'}}
        }
      }}
    expect{CfDeployer::ConfigValidation.new.validate(config)}.not_to raise_error
  end

  it "should get error if there is un-used inputs" do
    config = {
      :targets => ['base'],
      :application => 'myApp',
      :components =>{
        :base => {
          :inputs => {
             :vpc_id => "ab1234"
           },
          :settings => {
             :'raise-error-for-unused-inputs' => true,
           },
          :defined_parameters => {:vpcId => {:Default => 'ef2345'}}
        }
      }}
    expect{CfDeployer::ConfigValidation.new.validate(config)}.to raise_error("The input 'vpc_id' defined in the component 'base' is not used in the json template as a parameter")
  end

  it "should not get error if raise-error-for-unused-inputs is not set to true" do
    config = {
      :targets => ['base'],
      :application => 'myApp',
      :components =>{
        :base => {
          :inputs => {
             :vpc_id => "ab1234"
           },
          :settings => {
             :'raise-error-for-unused-inputs' => false,
           },
          :defined_parameters => {:vpcId => {:Default => 'ef2345'}}
        }
      }}
    expect{CfDeployer::ConfigValidation.new.validate(config)}.not_to raise_error
  end

  it "should get error if there is un-recognized option under the component level" do
    config = {
      :targets => ['base'],
      :application => 'myApp',
      :components =>{
        :base => {
           :boo => {}
          }
        },
      :environments => {},
      :tags => {}
      }
    expect{CfDeployer::ConfigValidation.new.validate(config)}.to raise_error("The option 'boo' of the component 'base' is not valid")
  end

  it "should get error if there is un-recognized option under the environment level" do
    config = {
      :targets => ['base'],
      :application => 'myApp',
      :components =>{
        :base => {}
        },
      :environments => {
        :dev => {
          :foo => {}
        }
      },
      :tags => {}
      }
      expect{ CfDeployer::ConfigValidation.new.validate(config) }.to raise_error("The option 'foo' of the environment 'dev' is not valid")
  end


  it "should get error if any output-reference settings do not have co-responding output" do
    config = {
      :targets => ['web', 'base'],
      :application => 'myApp',
      :components =>{
        :base => {
        },
        :web => {
          :inputs => {:vpc_id => {
            :component => 'base',
            :'output-key' => 'VPCID'
          }},
          :defined_parameters => {:vpc_id =>{}}
        }
      }}
    expect{CfDeployer::ConfigValidation.new.validate(config)}.to raise_error("No output 'VPCID' found in CF template of component base, which is referenced by input setting 'vpc_id' in component web")
  end

  it "should get error if application name is missing" do
    config = {
      :components => {
        :base =>{
        }
      }
    }
    expect{CfDeployer::ConfigValidation.new.validate(config)}.to raise_error("Application name is missing in config")
    config[:application] = ""
     expect{CfDeployer::ConfigValidation.new.validate(config)}.to raise_error("Application name is missing in config")
  end

  it "should get error if application name is too long (100 characters)" do
    config = {
      :targets => ['base'],
      :application => "a" * 101,
      :components => {
        :base =>{
        }
      }
    }
    expect{CfDeployer::ConfigValidation.new.validate(config)}.to raise_error("Application name cannot be longer than 100 and can only contain letters, numbers, '-' and '.'")
  end

    it "should get error if application name contains invalid characters" do
    config = {
      :targets => ['base'],
      :application => "a!@#%^&*()",
      :components => {
        :base =>{
        }
      }
    }
    expect{CfDeployer::ConfigValidation.new.validate(config)}.to raise_error("Application name cannot be longer than 100 and can only contain letters, numbers, '-' and '.'")
  end

    it "should get error if application name contains invalid character '_'" do
    config = {
      :targets => ['base'],
      :application => "a_b",
      :components => {
        :base =>{
        }
      }
    }
    expect{CfDeployer::ConfigValidation.new.validate(config)}.to raise_error("Application name cannot be longer than 100 and can only contain letters, numbers, '-' and '.'")
  end


  it "should get error if no component is defined in config" do
    config = {
      :application => "app",
      :components => {}
    }
    expect{CfDeployer::ConfigValidation.new.validate(config)}.to raise_error("At least one component must be defined in config")
  end

  it "should get error if component name is longer than 100" do
    component_name = ("a"*101)
    config = {
      :targets => [component_name],
      :application => "app",
      :components => { component_name.to_sym => {} }
    }
    expect{CfDeployer::ConfigValidation.new.validate(config)}.to raise_error("Component name cannot be longer than 100 and can only contain letters, numbers, '-' and '.': #{'a'*101}")
  end

  it "should get error if component name contains invalid characters" do
    config = {
      :targets => ['my@component', 'com_b'],
      :application => "app",
      :components => {
        :'my@component' => {},
        :com_b => {}
        }
    }
    expect{CfDeployer::ConfigValidation.new.validate(config)}.to raise_error(/Component name cannot be longer than 100 and can only contain letters, numbers, '-' and '.': my@component/)
    expect{CfDeployer::ConfigValidation.new.validate(config)}.to raise_error(/Component name cannot be longer than 100 and can only contain letters, numbers, '-' and '.': com_b/)
  end


  it "should get error if environment name is longer than 12" do
    config = {
      :targets => ['base'],
      :application => "app",
      :components => {
        :base => {}
        },
      :environments => {
        ("a"*13).to_sym => {}
      }
    }
    expect{CfDeployer::ConfigValidation.new.validate(config)}.to raise_error("Environment name cannot be longer than 12 and can only contain letters, numbers, '-' and '.': #{"a"*13}")
  end

  it "should get error if environment name contains invalid characters" do
    config = {
      :targets => ['base'],
      :application => "app",
      :components => {
        :base => {}
        },
      :environments => {
        :'a@ss' => {},
        :b_env => {}
      }
    }
    expect{CfDeployer::ConfigValidation.new.validate(config)}.to raise_error(/Environment name cannot be longer than 12 and can only contain letters, numbers, '-' and '.': a@ss/)
    expect{CfDeployer::ConfigValidation.new.validate(config)}.to raise_error(/Environment name cannot be longer than 12 and can only contain letters, numbers, '-' and '.': b_env/)
  end


  context 'cname-swap deployment strategy' do
    it 'should require dns-fqdn, dns-zone, and elb-name-output' do
      config = {
        :targets => ['base'],
        :application => 'app',
        :components => {
          :base => {
            :'deployment-strategy' => 'cname-swap',
            :settings => {
              :'elb-name-output' => 'somthing'
            },
            :defined_outputs => { :somthing => {} }
          }
        }
      }
      expect{CfDeployer::ConfigValidation.new.validate(config)}.to raise_error(/dns-fqdn is required when using cname-swap deployment-strategy/)
      expect{CfDeployer::ConfigValidation.new.validate(config)}.to raise_error(/dns-zone is required when using cname-swap deployment-strategy/)
    end

    it 'should require elb-name-output set to an existing output' do
      config = {
        :targets => ['base'],
        :application => 'app',
        :components => {
          :base => {
            :'deployment-strategy' => 'cname-swap',
            :settings => {
              :'elb-name-output' => 'somethingNotExist'
            }
          }
        }
      }
      expect{CfDeployer::ConfigValidation.new.validate(config)}.to raise_error(/'somethingNotExist' is not a CF stack output, which is required by cname-swap deployment/)
    end

    it 'should require auto-scaling-group-name-output set to an existing output' do
      config = {
        :targets => ['worker'],
        :application => 'app',
        :components => {
          :worker => {
            :'deployment-strategy' => 'cname-swap',
            :settings => {
              :'elb-name-output' => 'ELBID',
              :'auto-scaling-group-name-output' => ['somethingNotExist', 'IExist']
            },
            :defined_outputs => {
              :IExist => {},
              :ELBID => {}
            }
          }
        }
      }
      expect{CfDeployer::ConfigValidation.new.validate(config)}.to raise_error(/'\["somethingNotExist"\]' is not a CF stack output/)
    end
  end

  context 'auto-scaling-group swap deployment strategy' do
    it 'should require auto-scaling-group-name-output set to an existing output' do
      config = {
        :targets => ['worker'],
        :application => 'app',
        :components => {
          :worker => {
            :'deployment-strategy' => 'auto-scaling-group-swap',
            :settings => {
              :'auto-scaling-group-name-output' => ['somethingNotExist', 'IExist']
            },
            :defined_outputs => {
              :IExist => {}
            }
          }
        }
      }
      expect{CfDeployer::ConfigValidation.new.validate(config)}.to raise_error(/'\["somethingNotExist"\]' is not a CF stack output/)
    end
  end

  context 'create-or-update deployment strategy' do
    it 'should require auto-scaling-group-name-output set to an existing output' do
      config = {
        :targets => ['worker'],
        :application => 'app',
        :components => {
          :worker => {
            :'deployment-strategy' => 'create-or-update',
            :settings => {
              :'auto-scaling-group-name-output' => ['somethingNotExist', 'IExist']
            },
            :defined_outputs => {
              :IExist => {}
            }
          }
        }
      }
      expect{CfDeployer::ConfigValidation.new.validate(config)}.to raise_error(/'\["somethingNotExist"\]' is not a CF stack output/)
    end
  end

  context 'targets' do
    it 'should find invalid targets which are not defined in config as components' do
      config = {
        :targets => ['web', 'vpc'],
        :application => 'app',
        :components => {
          :base => {},
          :web => {}
        }
      }
      expect{CfDeployer::ConfigValidation.new.validate(config)}.to raise_error(/Found invalid deployment components \["vpc"\]/)
    end
  end
end

require 'spec_helper'

describe "application" do
  before :each do
    @context = {
      :application => 'myApp',
      :environment => 'dev',
      :targets => ['queue', 'web', 'db', 'base'],
      :components => {
          :queue => {
            :'depends-on' => [ 'base', 'db' ]
          },
          :web => {
            :'depends-on' => [ 'db', 'queue' ]
          },
          :db => {
            :'depends-on' => [ 'base']
          },
          :base => {
          }
        }
    }
    @app = CfDeployer::Application.new(@context)
    @base = @app.components.find{ |c| c.name == 'base' }
    @db = @app.components.find{ |c| c.name == 'db' }
    @queue = @app.components.find{ |c| c.name == 'queue' }
    @web = @app.components.find{ |c| c.name == 'web' }
  end

  it "application should get all components" do
    expect(@app.components.length).to eq(4)
    expect(@base).not_to be_nil
    expect(@db).not_to be_nil
    expect(@queue).not_to be_nil
    expect(@web).not_to be_nil
  end

  context "order components by dependencies" do
    it "should get components ordered by dependencies" do
        expect(@app.components).to eq([@base, @db, @queue, @web])
    end
  end

  context 'destroy' do
    it 'should destroy components starting with components without dependents' do
      log = ""
      allow(@base).to receive(:destroy) { log += "base "}
      allow(@db).to receive(:destroy) { log += "db "}
      allow(@queue).to receive(:destroy) { log += "queue "}
      allow(@web).to receive(:destroy) { log += "web "}
      @app.destroy
      expect(log).to eql("web queue db base ")
    end

    it 'should destroy specified components' do
      log = ""
      allow(@base).to receive(:destroy) { log += "base "}
      allow(@db).to receive(:destroy) { log += "db "}
      allow(@queue).to receive(:destroy) { log += "queue "}
      allow(@web).to receive(:destroy) { log += "web "}
      @context[:targets] = ['db', 'web', 'queue']
      @app.destroy
      expect(log).to eql("web queue db ")
    end
  end

  it "application should get components with their dependencies" do
    expect(@base.dependencies).to match_array([])
    expect(@db.dependencies).to match_array([@base])
    expect(@queue.dependencies).to match_array([@base, @db])
    expect(@web.dependencies).to match_array([@db, @queue])
  end

  it 'should get add components with their children' do
    expect(@base.children).to match_array([@db, @queue])
    expect(@db.children).to match_array([@web, @queue])
    expect(@queue.children).to match_array([@web])
    expect(@web.children).to match_array([])
  end

  describe '#switch' do

    let(:app) { CfDeployer::Application.new(@context.merge(:targets => ['base'])) }

    it 'should switch the specified component' do
      base = app.components.find { |c| c.name == 'base' }
      expect(base).to receive :switch
      app.switch
    end

    it 'should not switch components not specified' do
      db = app.components.find { |c| c.name == 'db' }
      queue = app.components.find { |c| c.name == 'queue' }
      web = app.components.find { |c| c.name == 'web' }
      base = app.components.find { |c| c.name == 'base' }
      allow(base).to receive :switch
      expect(db).not_to receive :switch
      expect(queue).not_to receive :switch
      expect(web).not_to receive :switch
      app.switch
    end
  end

  describe '#kill_inactive' do
    it 'should kill the inactive piece of a component' do
      @context[:targets] = ['base']
      app = CfDeployer::Application.new(@context)
      base = app.components.find{ |c| c.name == 'base' }
      expect(base).to receive(:kill_inactive)
      app.kill_inactive
    end
  end

  describe '#status' do
    it "should get each component's status" do
      expect(@base).to receive(:status)
      expect(@db).to receive(:status)
      expect(@queue).to receive(:status)
      expect(@web).to receive(:status)

      @app.status nil, 'all'
    end

    it 'should pass the get_resource_statuses flag down to the components' do
      expect(@base).to receive(:status).with(true)
      expect(@db).to receive(:status).with(true)
      expect(@queue).to receive(:status).with(true)
      expect(@web).to receive(:status).with(true)

      @app.status nil, 'all'
    end

    it 'should filter by component if specified' do
      expect(@base).not_to receive(:status)
      expect(@db).not_to receive(:status)
      expect(@queue).not_to receive(:status)

      expect(@web).to receive(:status).with(true)

      @app.status 'web', 'all'
    end
  end

  context "deploy components" do
     before :each do
        @log = ""
        allow(@base).to receive(:deploy) { @log += "base "}
        allow(@db).to receive(:deploy) { @log += "db "}
        allow(@queue).to receive(:deploy) { @log += "queue "}
        allow(@web).to receive(:deploy) { @log += "web "}
     end


    context "deploy all components" do
      it "should deploy all components if no component specified" do
        @app.deploy
        expect(@log).to eq("base db queue web ")
      end
    end

    context "deploy some components" do
      it "should deploy specified components" do
        @context[:targets] = ['web', 'db']
        @app.deploy
        expect(@log).to eq("db web ")
      end
    end
  end

  context '#json' do

    before :each do
      @log = ''
      allow(@base).to receive(:json) { @log += "base " }
      allow(@db).to receive(:json) { @log += "db " }
      allow(@queue).to receive(:json) { @log += "queue " }
      allow(@web).to receive(:json) { @log += "web " }
    end

    it 'should get json templates for all components' do
      @app.json
      expect(@log).to eq("base db queue web ")
    end

    it 'should get json templates for components specified' do
      @context[:targets] = ['web', 'db']
      @app.json
      expect(@log).to eq('db web ')
    end
  end
end

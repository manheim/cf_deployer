require 'spec_helper'

describe CfDeployer::Hook do
  before :all do
    Dir.mkdir 'tmp' unless Dir.exists?('tmp')
    @file = File.expand_path("../../../tmp/test_code.rb", __FILE__)
  end
  it 'should eval string as hook' do
    $result = nil
    context = { app: 'myApp'}
    CfDeployer::Hook.new('MyHook', "$result = context[:app]").run(context)
    expect($result).to eq('myApp')
  end

  it 'should log the hook name ' do
    context = { app: 'myApp'}
    expect(CfDeployer::Log).to receive(:info).with(/My Hook/)
    CfDeployer::Hook.new('My Hook', "$result = context[:app]").run(context)
  end

  it 'should duplicate context in hook' do
    $result = nil
    context = { app: 'myApp'}
    CfDeployer::Hook.new('MyHook', "context[:app] = 'app2'").run(context)
    expect(context[:app]).to eq('myApp')
  end

  it 'should timeout when executing hook in a string takes too long time' do
    $result = nil
    stub_const("CfDeployer::Defaults::Timeout", 10/1000.0)
    context = { app: 'myApp'}
    expect{CfDeployer::Hook.new('MyHook', "sleep 40/1000.0").run(context)}.to raise_error(Timeout::Error)
  end

  it 'should timeout when executing hook in a string takes too longer time than given timeout' do
    $result = nil
    context = { app: 'myApp'}
    expect{CfDeployer::Hook.new('MyHook', {code: "sleep 40/1000.0", timeout: 20/1000.0}).run(context)}.to raise_error(Timeout::Error)
  end

  it 'should excute code in a file' do
    code = <<-eos
      $result = context[:app]
    eos
    File.open(@file, 'w') {|f| f.write(code) }
    $result = nil
    config_dir = File.expand_path('../../samples', __FILE__)
    context = { app: 'myApp', config_dir: config_dir}
    CfDeployer::Hook.new('MyHook', {file: '../../tmp/test_code.rb'}).run(context)
    expect($result).to eq('myApp')
  end

  it 'should timeout when excuting code in a file takes too long time' do
    file = File.expand_path("../../tmp/test_code.rb", __FILE__)
    code = <<-eos
      sleep 40/1000.0
      $result = context[:app]
    eos
    File.open(@file, 'w') {|f| f.write(code) }
    $result = nil
    config_dir = File.expand_path('../../samples', __FILE__)
    context = { app: 'myApp', config_dir: config_dir}
    expect{CfDeployer::Hook.new('MyHook', {file: '../../tmp/test_code.rb', timeout: 20/1000.0}).run(context)}.to raise_error(Timeout::Error)
  end
end

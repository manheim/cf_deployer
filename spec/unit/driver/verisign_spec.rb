require 'spec_helper'

describe CfDeployer::Driver::Verisign do
  subject { CfDeployer::Driver::Verisign.new }

  describe ".find_alias_target" do
    it "should raise an error because it's not implemented yet" do
      expect { subject.find_alias_target('abc.com', 'foo') }.to raise_error('Not Implemented')
    end
  end

  describe ".set_alias_target" do
    it "should raise an error because it's not implemented yet" do
      expect { subject.set_alias_target('abc.com', 'foo', 'abc', 'def') }.to raise_error('Not Implemented')
    end

  end
end

require 'spec_helper'

describe 'DryRun' do

  context 'enable_for' do
    it 'enables dry run only during the block given' do
      CfDeployer::Driver::DryRun.disable_for do
        enabled_in_block = false

        CfDeployer::Driver::DryRun.enable_for do
          enabled_in_block = CfDeployer::Driver::DryRun.enabled?
        end

        expect(enabled_in_block).to be_truthy
        expect(CfDeployer::Driver::DryRun.enabled?).to be_falsey
      end
    end

    it 'resets dry run, even if the given block throws an exception' do
      CfDeployer::Driver::DryRun.disable_for do
        enabled_in_block = false

        expect do
          CfDeployer::Driver::DryRun.enable_for do
            enabled_in_block = CfDeployer::Driver::DryRun.enabled?
            raise 'boom'
          end
        end.to raise_error('boom')

        expect(enabled_in_block).to be_truthy
        expect(CfDeployer::Driver::DryRun.enabled?).to be_falsey
      end
    end
  end

  context 'disable_for' do
    it 'disables dry run only during the block given' do
      CfDeployer::Driver::DryRun.enable_for do
        enabled_in_block = nil

        CfDeployer::Driver::DryRun.disable_for do
          enabled_in_block = CfDeployer::Driver::DryRun.enabled?
        end

        expect(enabled_in_block).to be_falsey
        expect(CfDeployer::Driver::DryRun.enabled?).to be_truthy
      end
    end

    it 'resets dry run, even if the given block throws an exception' do
      CfDeployer::Driver::DryRun.enable_for do
        enabled_in_block = nil

        expect do
          CfDeployer::Driver::DryRun.disable_for do
            enabled_in_block = CfDeployer::Driver::DryRun.enabled?
            raise 'boom'
          end
        end.to raise_error('boom')

        expect(enabled_in_block).to be_falsey
        expect(CfDeployer::Driver::DryRun.enabled?).to be_truthy
      end
    end
  end
end

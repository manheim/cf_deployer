require 'spec_helper'

describe "status_presenter" do

  before do
    @presenter = CfDeployer::StatusPresenter.new({}, 'all')
  end

  context "#filter_for_verbosity" do
    it "should filter out all resources if the verbosity is 'stacks'" do
      info = { 
        :web => {
          :stack1 => {
            :status => :ready,
            :resources => { :some_resource_type => [ :resource_1, :resource_2 ] }            
          }
        }
      }

      stacks_presenter = CfDeployer::StatusPresenter.new({}, 'stacks')
      filtered_info = stacks_presenter.send :filter_for_verbosity, info

      expect(filtered_info[:resources]).to eq(nil)
    end

    it "should only keep :instances and :asg_instances when verbosity is 'instances'" do
      info = { 
        :web => {
          :stack1 => {
            :status => :ready,
            :resources => { 
              :instances => [ :instance_1 ],
              :asg_instances => [ :asg_instance_1 ],
              :some_other_resource => [ :other_resource ]
            }
          }
        }
      }

      instances__presenter = CfDeployer::StatusPresenter.new({}, 'instances')
      filtered_info = instances__presenter.send :filter_for_verbosity, info

      expect(filtered_info[:web][:stack1][:resources][:instances]).to eq(info[:web][:stack1][:resources][:instances])
      expect(filtered_info[:web][:stack1][:resources][:asg_instances]).to eq(info[:web][:stack1][:resources][:asg_instances])
      expect(filtered_info[:web][:stack1][:resources][:some_other_resource]).to eq(nil)
    end
  end

  context "#tableize" do
    before do
      @table_data = [
        [ 'r1c1',
          'r2c1',
          'r3c1'
        ],
        [ 'r1c2',
          'r2c2'
        ]
      ]

      @table_output = @presenter.send :tableize, @table_data
    end

    it "should have one more row than the max of each column's number of rows" do
      expect(@table_output.size).to eq(4)
    end

    it "should have a table seperator as the last row" do
      expect(@table_output.last).to eq(@presenter.send :table_seperator)
    end

    it "should draw a column seperator and pad the left column" do
      expected_pad = ' ' * (CfDeployer::StatusPresenter::UNPADDED_TABLE_CELL_WIDTH - CfDeployer::StatusPresenter::PAD.size)
      expected_row = @table_data[0][0] + expected_pad + '|' + @table_data[1][0]
      expect(@table_output.first).to eq(expected_row)
    end
  end

  context "#middle_truncate_ljust" do
    it "should replace the middle of a long string with an elipsis" do
      long_str = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
      truncated_str = @presenter.send :middle_truncate_ljust, long_str, 40
      expect(truncated_str).to eq('abcdefghijklmnopq...GHIJKLMNOPQRSTUVWXYZ')
      expect(truncated_str.size).to eq(40)
    end
  end

  context "#visible_length" do
    it "should return the length of the string without ANSI color code characters" do
      colored_string = "a \e[31mcolored\e[0m string"
      expect(@presenter.send(:visible_length, colored_string)).to eq(16)
    end
  end

  context "#invisible_length" do
    it "should return the length of the ANSI color code characters" do
      colored_string = "a \e[31mcolored\e[0m string"
      expect(@presenter.send(:invisible_length, colored_string)).to eq(9)
    end
  end

  context "#centered" do
    it "should rjust a string to the center of the table" do
      expect(@presenter.send(:centered, 'Some String')).to eq('                                                                                 Some String')
    end
  end

end
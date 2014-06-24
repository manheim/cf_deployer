require 'rainbow'
require 'rainbow/ext/string'

module CfDeployer
  class StatusPresenter

    VERBOSITY_3_SKIP = ['AWS::AutoScaling::AutoScalingGroup','AWS::EC2::Instance',:asg_instances, :instances]

    PAD = "  "
    UNPADDED_TABLE_CELL_WIDTH = 85

    def initialize status_info, verbosity
      @verbosity = verbosity
      @info = status_info
      @output = []
    end

    def to_json
      filter_for_verbosity(@info).to_json
    end

    def output
      @output << table_seperator
      @info.each do |component_name, stacks_hash|
        @output << "\n#{centered(component_name.upcase)}\n"
        @output << table_seperator
        stack_cells = []
        stacks_hash.each do |stack_name, stack_hash|
          stack_output = ['']

          stack_output << PAD + [ colorized_stack_name(stack_name, stack_hash),
                            stack_active_str(stack_hash[:active]).ljust(15),
                            stack_hash[:status].capitalize
                          ].join(PAD)

          if stack_hash[:resources]  && @verbosity != 'stacks'
            instances_status stack_output, component_name, stack_name, stack_hash[:resources][:instances], false
            asgs_status stack_output, component_name, stack_name, stack_hash[:resources][:asg_instances]
            resource_status stack_output, stack_hash[:resources] if @verbosity == 'all'
          end
          stack_output << ''
          stack_cells << stack_output
        end
        stack_cells[1] ||= ['']
        @output += tableize( stack_cells )
      end
      @output.join "\n"
    end

    private

    def filter_for_verbosity info_hash
      if @verbosity == 'stacks'
        info_hash.each do |component, component_hash|
          component_hash.each { |stack, stack_hash| stack_hash.delete :resources }
        end
      elsif @verbosity == 'instances'
        info_hash.each do |component, component_hash|
          component_hash.each do |stack, stack_hash|
            if stack_hash[:resources]
              stack_hash[:resources].select! do |resource_type, resources|
                [:instances, :asg_instances].include? resource_type
              end
            end
          end
        end
      end
      info_hash
    end

    def colorized_stack_name stack_name, stack_hash
      stack_color = case stack_name.split('').last
        when 'B' then :cyan
        when 'G' then :green
        else :white
      end
      colorized_stack_name = " #{stack_name} ".color(stack_color).bright
      stack_hash[:active] ? colorized_stack_name.inverse : colorized_stack_name
    end

    def stack_active_str active
      case active
        when true then 'Active'
        when false then 'Inactive'
        else ''
      end
    end

    def asgs_status output, component_name, stack_name, asg_hash
      return if asg_hash.empty?
      output << ''
      output << "#{PAD * 2}AutoScalingGroups:"
      asg_hash.each do |asg_name, asg_instances|
        asg_color = status_color @info[component_name][stack_name][:resources]['AWS::AutoScaling::AutoScalingGroup'][asg_name]
        output << ''
        output << "#{PAD * 3}#{ Rainbow(asg_name).color asg_color }"
        instances_status output, component_name, stack_name, asg_instances, true
      end
    end

    def instances_status output, component_name, stack_name, instances_hash, in_asg
      pad = PAD * 2
      output << ''
      output << "#{pad}Instances:" if (instances_hash.any? && !in_asg)
      instances_hash.each do |instance_id, instance|
        instance_pad = in_asg ? pad + PAD : pad
        instance_color = instance_status_color instance[:status]
        instance_line_parts = [ Rainbow(instance_id).color(instance_color),
                                instance[:public_ip_address],
                                instance[:private_ip_address],
                                instance[:image_id],
                                instance[:key_pair]
                              ]
        output << "#{PAD}#{instance_pad}" + instance_line_parts.join(PAD)
      end
    end

    def resource_status output, resource_hash
      resources_to_report = resource_hash.reject { |resource_type| VERBOSITY_3_SKIP.include? resource_type }
      max_length = resources_to_report.map { |rtype, r| r.keys }.flatten.group_by(&:size).max.last.first.size
      new_max = [ max_length, (UNPADDED_TABLE_CELL_WIDTH - 17 - (PAD.size * 4))].sort.first

      resources_to_report.each do |resource_type, resources|
        output << ''
        output << "#{PAD * 2}#{resource_type.split('::').last}"
        resources.each do |resource_id, resource_status|
          truncated_id = middle_truncate_ljust(resource_id, new_max).color(status_color(resource_status))
          output << "#{PAD * 3}#{truncated_id}#{PAD}#{resource_status}"
        end
      end
    end

    def instance_status_color status
      CfDeployer::Driver::Instance::GOOD_STATUSES.include?(status) ? :green : :red
    end

    def status_color status
      status = status.downcase.to_sym
      if CfDeployer::Stack::READY_STATS.include? status
        :green
      elsif CfDeployer::Stack::FAILED_STATS.include? status
        :red
      else
        :white
      end
    end

    def tableize stack_cells
      my_output = []

      (col1, col2) = stack_cells
      rows = stack_cells.map(&:size).max

      rows.times do |i|
        col1[i] ||= ''
        col2[i] ||= ''

        line = ''
        line << col1[i].ljust(UNPADDED_TABLE_CELL_WIDTH + PAD.size + invisible_length(col1[i]))
        line << '|'
        line << col2[i]
        my_output << line
      end
      my_output << table_seperator
      my_output
    end

    def middle_truncate_ljust str, len
      return str.ljust(len) if str.size <= len

      replace_start = (len / 2).to_i - 4
      replace_end = str.size - (len / 2).to_i
      truncated  = str[0..replace_start] + '...' + str[replace_end..str.size]
      truncated.ljust len
    end

    def invisible_length str
      str.size - visible_length(str)
    end

    def visible_length str
      str.gsub(/\e\[[\d;]+m/,'').size
    end

    def table_seperator
      "-" * (UNPADDED_TABLE_CELL_WIDTH + PAD.size) * 2
    end

    def centered the_string
      width = (UNPADDED_TABLE_CELL_WIDTH + PAD.size) + (the_string.size / 2).to_i
      the_string.rjust width
    end

  end
end

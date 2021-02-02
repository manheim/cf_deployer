module Fakes
  class AWSRoute53
    attr_reader :fail_counter, :hosted_zones, :client
    def initialize(opts = {})
      @hosted_zones = opts[:hosted_zones]

      @times_to_fail = opts[:times_to_fail]
      @fail_counter = 0
    end

    def list_hosted_zones_by_name
      OpenStruct.new(hosted_zones: hosted_zones)
    end

    def change_resource_record_sets(*args)
      @fail_counter = @fail_counter + 1
      raise 'Error' if @fail_counter <= @times_to_fail
    end
  end
end

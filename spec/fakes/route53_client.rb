module Fakes
  class AWSRoute53
    attr_reader :fail_counter, :hosted_zones, :client
    def initialize(opts = {})
      @client = AWSRoute53Client.new(opts)
      @hosted_zones = opts[:hosted_zones]
      @fail_counter = 0
    end
  end

  class AWSRoute53Client
    attr_reader :fail_counter
    def initialize(opts = {})
      @times_to_fail = opts[:times_to_fail]
      @fail_counter = 0
    end

    def change_resource_record_sets(*args)
      @fail_counter = @fail_counter + 1
      raise 'Error' if @fail_counter <= @times_to_fail
    end
  end
end

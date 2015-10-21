module Fakes
  class Stack
    attr_reader :outputs, :parameters
    attr_accessor :resource_statuses

    def initialize(options)
      @exists = options[:exists?].nil? ? true : options[:exists?]
      @outputs = options[:outputs] || {}
      @parameters = options[:parameters] || {}
      @name = options[:name] || 'Unnamed'
      @status = options[:status] || :ready
      @resource_statuses = {}
    end

    def inspect
      "#{self.class}<#{@name}>"
    end
    alias_method :to_s, :inspect

    def output(key)
      raise 'Stack is dead' unless @exists
      @outputs[key]
    end
    alias_method :find_output, :output

    def set_output(key, value)
      @outputs[key] = value
    end

    def live!
      @exists = true
    end

    def die!
      @exists = false
    end

    def exists?
      @exists
    end

    def delete
      @exists = false
      @deployed = false
      @deleted = true
    end

    def deploy
      @exists = true
      @deployed = true
    end

    def deployed?
      @deployed
    end

    def deleted?
      @deleted
    end

    def name
      @name
    end

    def status
      @status
    end
  end
end

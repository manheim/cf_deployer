module Fakes
  class Instance

    SIMPLE_ATTRIBS = [ :id, :status, :public_ip_address, :private_ip_address, :image_id ]

    attr_reader *SIMPLE_ATTRIBS
    attr_reader :key_pair

    def initialize(options)
      defaults = {
        :id => 'i-abcd1234',
        :status => :running,
        :public_ip_address => '1.2.3.4',
        :private_ip_address => '192.168.100.200',
        :image_id => 'ami-abcd1234',
        :key_pair => 'awesome_users'
      }

      SIMPLE_ATTRIBS.each do |attrib|
        instance_variable_set "@#{attrib}", (options[attrib] || defaults[attrib])
      end

      @key_pair = ::Aws::EC2::KeyPair.new (options[:key_pair] || defaults[:key_pair] )
    end

    def inspect
      "#{self.class}<#{@name}>"
    end
    alias_method :to_s, :inspect

  end
end
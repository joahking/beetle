require 'ruby-debug'
Debugger.start
module Beetle
  # raised when a handler is tried to access which doesn't exist
  class UnknownHandlerError < Error; end

  class SimpleClient < Client
    private :register_binding, :register_queue, :register_exchange

    def register_message(message_name, options={})
      options.assert_valid_keys(:group, :redundant)
      group = options.delete(:group)
      options[:key] = "#{group}.#{message_name}" if group
      options[:exchange] = "beetle"
      super
    end

    # FIXME: move into some small and nice methods
    def register_handler(handler, *messages_to_listen, &block)
      raise ArgumentError.new("Either a handler class or a block (in case of a named handler) must be given") if handler.is_a?(String) && !block_given?
      queue = queue_name_from_handler(handler)
      raise ConfigurationError.new("Handler name #{queue} collides with a message") if messages[queue]
      handler_opts = messages_to_listen.last.is_a?(Hash) ? messages_to_listen.pop : {}
      queue_opts = handler_opts.slice!(:errback, :failback, :groups)

      begin
        register_queue queue, queue_opts.merge({:exchange => 'beetle'})
      rescue ConfigurationError
        raise ConfigurationError.new("Handler names must be unique")
      end

      messages_to_listen.each do |message_name|
        message = messages[message_name.to_s]
        raise ConfigurationError.new("Message #{message_name} is undefined") unless message
        register_binding queue, :key => message[:key], :exchange => "beetle"
      end

      if groups = handler_opts.delete(:groups)
        Array(groups).each do |group|
          raise ConfigurationError.new("no messages for group #{group} specified") unless messages.any? {|_, opts| opts[:key] =~ /^#{group}\./}
          register_binding queue, :key => "#{group}.#", :exchange => "beetle"
        end
      end

      if handler.is_a?(Class)
        super(queue, handler, handler_opts)
      else
        super(queue, handler_opts, &block)
      end
    end
    
    def handler(handler)
      handler_name = queue_name_from_handler(handler)
      if queues.has_key? handler_name
        SimpleHandler.new(handler_name, self)
      else
        raise UnknownHandlerError.new
      end
    end

    def purge(handler)
      super(queue_name_from_handler(handler))
    end

    private
    def queue_name_from_handler(handler)
      handler.is_a?(Class) ? handler.name.underscore.gsub('/', '.') : handler.to_s.gsub(' ', '_').underscore
    end
    
    class SimpleHandler # nodoc
      def initialize(handler_name, client)
        @client = client
        @name = handler_name
      end

      def listens_to?(message_name)
        message = @client.messages[message_name.to_s]
        @client.bindings[@name].any? do |binding|
        raise ConfigurationError.new("Message #{message_name} not defined") unless message
        same_exchange = binding[:exchange] == message[:exchange]
        key_matches = if binding[:key] =~ /(.+)\.\#$/
                        group = $1
                        !!(message[:key] =~ /^#{group}\..+/)
                      else
                        binding[:key] == message[:key]
                      end
        key_matches && same_exchange
        end
      end
    end
  end
end
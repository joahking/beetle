require 'amqp'
require 'mq'
require 'bunny'
require 'uuid4r'
require 'active_support'
require 'redis'

module Beetle

  class Error < StandardError; end
  class ConfigurationError < Error; end

  EXCHANGE_CREATION_KEYS  = [:auto_delete, :durable, :internal, :nowait, :passive]
  QUEUE_CREATION_KEYS     = [:passive, :durable, :exclusive, :auto_delete, :no_wait]
  QUEUE_BINDING_KEYS      = [:key, :no_wait]
  PUBLISHING_KEYS         = [:key, :mandatory, :immediate, :persistent, :reply_to]

  lib_dir = File.expand_path(File.dirname(__FILE__) + '/beetle/')
  Dir["#{lib_dir}/*.rb"].each do |libfile|
    autoload File.basename(libfile)[/(.*)\.rb/, 1].classify, libfile
  end

  def self.configuration
    yield config
  end

  protected

  def self.config
    @config ||= Configuration.new
  end

  # FIXME: there should be a better way to test
  if defined?(Mocha)
    def self.reraise_expectation_errors!
      raise if $!.is_a?(Mocha::ExpectationError)
    end
  else
    def self.reraise_expectation_errors!
    end
  end

end

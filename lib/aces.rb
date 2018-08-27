require "aces/version"
require "active_support"

module Aces
  class ResultMissing < StandardError; end
  class UnhandledResult < StandardError; end

  module Service
    extend ActiveSupport::Concern

    module ClassMethods
      def call(*args)
        set(
          *args,
          success: Aces::ConfiguredService::NOOP,
          failure: Aces::ConfiguredService::NOOP,
        ).call
      end

      def set(*positional_arguments, service: self, success: nil, failure: nil, **keyword_arguments)
        Aces::ConfiguredService.new(
          service: service,
          success: success,
          failure: failure,
          positional_arguments: positional_arguments,
          keyword_arguments: keyword_arguments,
        )
      end
    end

    def success(**attributes)
      Aces::Result.new(success: true, **attributes)
    end

    def failure(**attributes)
      Aces::Result.new(success: false, **attributes)
    end
  end

  class ConfiguredService
    attr_reader :configured_positional_arguments, :configured_keyword_arguments, :service, :success, :failure

    NOOP = ->(_result) {}
    IDENTITY = ->(result) { result }
    UNCONFIGURED = ->(_result) { raise UnhandledResult }

    def initialize(service:, success: nil, failure: nil, positional_arguments:, keyword_arguments:)
      @service = service
      @success = success == :identity ? IDENTITY : (success || UNCONFIGURED)
      @failure = failure == :identity ? IDENTITY : (failure || UNCONFIGURED)
      @configured_positional_arguments = positional_arguments
      @configured_keyword_arguments = keyword_arguments
    end

    def set(*positional_arguments, **keyword_arguments)
      configured_positional_arguments.push *positional_arguments unless positional_arguments.size.zero?
      configured_keyword_arguments.merge!(keyword_arguments)
    end

    def call(*callsite_positional_arguments, **callsite_keyword_arguments)
      combined_arguments = configured_positional_arguments + callsite_positional_arguments
      combined_keyword_arguments = configured_keyword_arguments.merge(callsite_keyword_arguments)
      combined_arguments.push combined_keyword_arguments if combined_keyword_arguments.keys.any?

      service.new(*combined_arguments).call.tap do |result|
        raise ResultMissing, "#{service}.call didn't return a result!" unless result.is_a?(Aces::Result)
        callback = result.success? ? success : failure
        callback.call(result) if callback.respond_to?(:call)
      end
    end
  end

  class Result
    attr_reader :failure, :attributes

    def initialize(success: true, failure: !success, **attributes)
      @failure = !!failure
      @attributes = attributes
    end

    def success?
      !failure?
    end

    def failure?
      failure
    end

    def merge(other_result)
      next_attributes = attributes.merge(other_result.attributes)
      next_failure = failure || other_result.failure
      self.class.new(failure: failure, **next_attributes)
    end

    def respond_to_missing?(method_name, _include_private = false)
      attributes.key?(method_name)
    end

    def method_missing(method_name, *args)
      attributes.fetch(method_name) { super }
    end
  end

  class Lambda
    include Aces::Service

    attr_reader :arguments, :callable

    def initialize(*positional_arguments, callable:, **keyword_arguments)
      @arguments = positional_arguments
      @arguments.push(keyword_arguments) if keyword_arguments.any?
      @callable = callable
    end

    def call
      instance_exec(*arguments, &callable)
    end
  end

  def self.lambda(success: Aces::ConfiguredService::NOOP, failure: Aces::ConfiguredService::NOOP)
    Aces::Lambda.set(callable: Proc.new, success: success, failure: failure)
  end
end

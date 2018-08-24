require "aces/version"
require "active_support"

module Aces
  class ResultMissing < StandardError; end
  class UnhandledResult < StandardError; end

  module Service
    extend ActiveSupport::Concern

    module ClassMethods
      def call(*args)
        new(*args).call.tap do |result|
          raise ResultMissing, "#{name}.call didn't return a result!" unless result.is_a?(Aces::Result)
        end
      end

      def set(success: nil, failure: nil)
        Aces::ConfiguredService.new(
          service: self,
          success: success,
          failure: failure,
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
    attr_reader :service, :success, :failure

    UNCONFIGURED = ->(_result) { raise UnhandledResult }

    def initialize(service:, success:, failure:)
      @service = service
      @success = success || UNCONFIGURED
      @failure = failure || UNCONFIGURED
    end

    def call(*args)
      service.call(*args).tap do |result|
        callback = result.success? ? success : failure
        callback.call(result)
      end
    end
  end

  class Result
    attr_reader :success, :attributes

    def initialize(success: true, **attributes)
      @success = success
      @attributes = attributes
    end

    def success?
      success
    end

    def failure?
      !success
    end

    def respond_to_missing?(method_name, _include_private = false)
      attributes.key?(method_name)
    end

    def method_missing(method_name, *args)
      attributes.fetch(method_name) { super }
    end
  end
end

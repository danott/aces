require "test_helper"
require "pry"

class AcesTest < Minitest::Test
  class SuccessService
    include Aces::Service

    attr_reader :value

    def initialize(value)
      @value = value
    end

    def call
      success value: value
    end
  end

  class FailureService
    include Aces::Service

    attr_reader :value

    def initialize(value)
      @value = value
    end

    def call
      failure value: value
    end
  end

  class MalformedService
    include Aces::Service

    def call
      "return value is not an Aces::Result"
    end
  end

  def test_that_it_has_a_version_number
    refute_nil ::Aces::VERSION
  end

  def test_service_must_return_a_result
    assert_raises Aces::ResultMissing do
      MalformedService.call
    end
  end

  def test_service_result_shape
    value = "I am a return value!"

    SuccessService.call(value).tap do |success_service_result|
      assert_predicate success_service_result, :success?
      refute_predicate success_service_result, :failure?
      assert_equal value, success_service_result.value
      assert_raises(NoMethodError) { success_service_result.not_a_method }
    end

    FailureService.call(value).tap do |failure_service_result|
      refute_predicate failure_service_result, :success?
      assert_predicate failure_service_result, :failure?
      assert_equal value, failure_service_result.value
      assert_raises(NoMethodError) { failure_service_result.not_a_method }
    end
  end

  def test_configured_services
    value = "I am a return value!"

    configured_success_service = SuccessService.set(
      success: ->(result) { assert_equal value, result.value },
      failure: ->(_result) { flunk "Should not be called" },
    )
    configured_failure_service = FailureService.set(
      success: ->(_result) { flunk "Should not be called" },
      failure: ->(result) { assert_equal value, result.value },
    )

    assert_equal value, configured_success_service.call(value).value
    assert_equal value, configured_failure_service.call(value).value
  end

  def test_configured_services_force_you_to_handle
    assert_raises Aces::UnhandledResult do
      SuccessService.set(failure: ->(_result) { flunk "Should not be called" }).call(nil)
    end

    assert_raises Aces::UnhandledResult do
      FailureService.set(success: ->(_result) { flunk "Should not be called" }).call(nil)
    end
  end
end

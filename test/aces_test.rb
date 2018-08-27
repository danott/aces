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

  class CurriedService
    include Aces::Service

    def initialize(first, second, a:, b:)
      @first = first
      @second = second
      @a = a
      @b = b
    end

    def call
      success first: @first, second: @second, a: @a, b: @b
    end
  end

  def test_currying_args_as_a_theoretical_api
    prepared = CurriedService.set(success: :identity)
    prepared.set("first_position",  b: "keyword_b")
    result = prepared.call("second_position", a: "keyword_a")
    assert_equal "first_position", result.first
    assert_equal "second_position", result.second
    assert_equal "keyword_a", result.a
    assert_equal "keyword_b", result.b
  end

  def test_currying_plus_composing_as_a_theoretical_api
    skip "None of these test services exist"

    calculate_tax = CalculateTax.set(subtotal_amount: item.amount, state: "TX")
    charge_card = ChargeCard.set(device: some_credit_card, subtotal_amount: item.amount)
    create_shipping_label = CreateShippingLabel.set(address: "wherever")

    # manual with explit post conditionals
    result = calculate_tax.call
    result = result.merge charge_card.call(taxes_amount: result.taxes_amount) if result.success?
    result = result.merge create_shipping_label.call if result.success?

    # or *magic* with procs?
    result = calculate_tax.call
    result = result.chain { charge_card.call(taxes_amount: result.taxes_amount) }
    result = result.chain { create_shipping_label.call }
  end

  def test_producing_cheap_services_from_lambdas
    cheap_service = Aces.lambda do |succeed, value:|
      succeed ? success(value: value) : failure(value: value)
    end

    result = cheap_service.call(true, value: 23)

    assert_predicate result, :success?
    assert_equal 23, result.value

    result = cheap_service.call(false, value: 42)

    refute_predicate result, :success?
    assert_equal 42, result.value

    cheap_malformed_service = Aces.lambda do |echo_value|
      echo_value
    end

    assert_raises Aces::ResultMissing do
      cheap_malformed_service.call "dunk"
    end
  end
end

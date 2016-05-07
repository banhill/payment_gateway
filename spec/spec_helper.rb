require 'bundler/setup'
Bundler.setup

require 'payment_gateway'
require 'webmock/rspec'
require File.expand_path('../support/fake_payment_gateway', __FILE__)

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.before(:each) do
    stub_request(:any, /paymentgateway.hu/).to_rack(FakePaymentGateway)
  end
end

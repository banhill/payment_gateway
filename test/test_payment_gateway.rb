require 'minitest'
require 'minitest/autorun'
require 'payment_gateway'

class PaymentGatewayTest < Minitest::Test
  # let's do every assertion separately to always know what exactly went wrong

  def test_configure_legal
    conf_hash = {
        :provider => 'PayPal',
        :store => 'PhantomStore',
        :currency => 'USD',
        :language => 'EN',
        :response_mode => 'XML',
        :host => 'fake.host',
        :header_host => 'test.paymentgateway.hu',
        :port => '3333',
        :use_ssl => 'true',
        :auto_commit_providers => ['MPP2'],
        :auto_commit_not_implemented => ['OTPayMP'],
        :app_host => 'localhost'
    }
    PaymentGateway.configure(conf_hash)
    assert PaymentGateway.config == conf_hash
  end

  def test_configure_illegal
    conf_hash = {
        :provider => 'PayPal',
        :store => 'PhantomStore',
        :currency => 'USD',
        :language => 'EN',
        :response_mode => 'XML',
        :host => 'fake.host',
        :header_host => 'test.paymentgateway.hu',
        :port => '3333',
        :use_ssl => 'true',
        :auto_commit_providers => ['MPP2'],
        :auto_commit_not_implemented => ['OTPayMP'],
        :app_host => 'localhost',
        :foobar => 'illegal'
    }
    PaymentGateway.configure(conf_hash)
    assert PaymentGateway.config != conf_hash
  end

  def test_init
    assert false
  end

  def test_start_payment
    PaymentGateway.configure({:header_host => 'my.fake.host'})
    assert PaymentGateway.new.start_payment('order_id_123', 'tr_id_123') == 'http://my.fake.host/Start?TransactionId=tr_id_123'
  end

  def test_close
    assert false
  end

  def test_result
    assert false
  end

end

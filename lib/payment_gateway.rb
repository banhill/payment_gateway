require 'cgi'
require 'logger'
require 'yaml'
require 'rest-client'
require 'base64'

class DefaultLogger
  attr_accessor :request, :response

  def log(request, response)
    self.request           ||= request
    self.response          ||= response

    puts self.inspect
  end

  def inspect
    res = ''
    res += ' Request: ' + (self.request ? self.request.to_s : '')
    res += ' Response: ' + (self.response ? self.response.to_s : '')

    return res
  rescue => e
    # don't raise an exception, default logger fails silently
    return e.message
  end

end # Default logger

class PaymentGateway
  # constants for basic URLS and method names
  REST_API = '/api/rest'
  TEST_HOST = 'test.paymentgateway.hu'
  PROD_HOST = 'paymentgateway.hu'
  INIT   = 'Init'
  RESULT = 'Result'
  CLOSE  = 'Close'

  @@config = {
    provider: 'OTP',
    store: 'sdk_test',
    currency: 'HUF',
    language: 'HU',
    host: '',
    header_host: PROD_HOST,
    port: '',
    use_ssl: 'true',
    auto_commit_providers: ['MPP2'],
    auto_commit_not_implemented: ['OTPayMP'],
    app_host: '',
    api_key: '86af3-80e4f-f8228-9498f-910ad'
  }

  @@valid_config_keys = @@config.keys

  attr_accessor :provider, :response_url, :amount, :currency, :order_id, :user_id, :language, :approved, :transaction_id

  # config through hash
  def self.configure(opts = {})
    opts.each { |k, v| @@config[k.to_sym] = v if @@valid_config_keys.include?(k.to_sym) }
  end

  # config through yaml file
  def self.configure_with(path_to_yaml_file)
    begin
      config = YAML::load(IO.read(path_to_yaml_file))
    rescue Errno::ENOENT
      log(:warning, "YAML configuration file couldn't be found. Using defaults.")
    rescue Psych::SyntaxError
      log(:warning, 'YAML configuration file contains invalid syntax. Using defaults.')
    end

    configure(config)
  end

  def self.config
    @@config
  end

  def initialize(provider = @@config[:provider])
    self.provider = provider
  end

  # The +init+ instance method initializes the payment transaction at
  # PaymentGateway. Returns response as a hash.
  # === Attributes
  # * _provider_ optional, initialize sets it to defaults
  # * _response_url_ mandatory, relative to the app host
  # * _amount_ amount to charge the customer
  # * _order_id_ optional, vendor-specific id of the order
  # * _user_id_ optional, vendor-specific id of the user
  # === Parameters
  # * _logger_ optional logger to use (must implement <tt>log(request_param_string, response_param_string)</tt>)
  # === Example
  #  pg = PaymentGateway.new
  #  pg.provider = provider
  #  pg.response_url = some_url
  #  pg.amount = 3000
  #  pg.currency = "HUF"
  #  pg.order_id = "order123"
  #  pg.user_id = "user123"
  #  pg.language = "HU"
  #  response = pg.init(logger)
  def init(logger = DefaultLogger.new)
    request_hash = {
      'ProviderName' => provider,
      'StoreName'    => @@config[:store],
      'ResponseUrl'  => CGI::escape(@@config[:app_host] + response_url),
      'Amount'       => amount.to_s,
      'OrderId'      => order_id.to_s,
      'UserId'       => user_id.to_s,
      'Currency'     => @@config[:currency],
      'Language'     => @@config[:language],
      'AutoCommit'   => (@@config[:auto_commit_providers].include?(provider).to_s unless @@config[:auto_commit_not_implemented].include?(provider))
    }

    result = submit_request(INIT, request_hash)

    logger.log(request_hash.to_s, result.to_s)

    return result

  rescue => e
    logger.log(request_hash.to_s, result.to_s)
    raise e
  end

  # The +start+ instance method composes the url the user has to be redirected to.
  # === Attributes
  # * _transaction_id_ mandatory
  # === Example
  # pg = PaymentGateway.new
  # pg.transaction_id = '123456789abc'
  # redirect_to pg.start
  def start(logger = DefaultLogger.new)
    url = 'http://' + @@config[:header_host] + '/Start?TransactionId=' + transaction_id.to_s
    logger.log(url, nil)
    url
  end

  # The +result+ instance method queries the status of the payment from PG, returns
  # result in a hash.
  # === Attributes
  # * _transaction_id_ mandatory, PG transaction id, returned by init
  # === Parameters
  # * _logger_ (optional) = logger to use (must implement <tt>log(request_param_string, response_param_string)</tt>)
  # === Example
  #  pg = PaymentGateway.new
  #  pg.transaction_id = '123456789abc'
  #  result = pg.result
  def result(logger = DefaultLogger.new)
    request_hash = {
      'TransactionId' => transaction_id.to_s
    }

    result = submit_request(RESULT, request_hash)

    logger.log(request_hash.to_s, result.to_s)

    return result

  rescue => e
    logger.log(request_hash.to_s, result.to_s)
    raise e
  end

  # The +close+ instance method finalizes the payment in one of the following
  # ways: 1) cancel the authorization hold on the customer's credit or debit card,
  # or 2) submit the transaction and thus effectively charging the customer's
  # card.
  # === Attributes
  # * _transaction_id_ mandatory PG transaction id, returned by init
  # * _approve_ (optional, boolean) cancel, or submit, defaults to true
  # === Parameters
  # * _logger_ (optional) = logger to use (must implement <tt>log(request_param_string, response_param_string)</tt>
  # === Example
  #  pg = PaymentGateway.new
  #  pg.transaction_id = '1234hfajl'
  #  pg.approve = false
  #  pg.close
  def close(logger = DefaultLogger.new)
    request_hash = {
      'TransactionId' => transaction_id.to_s,
      'Approved' => approved.to_s || true
    }

    result = submit_request(CLOSE, request_hash)

    logger.log(request_hash.to_s, result.to_s)

    return result

  rescue => e
    logger.log(request_hash.to_s, result.to_s)
    raise e
  end

  private

  # +submit_request+ takes the method name and the request parameters as a hash,
  # uses RestClient to submit the request to the PaymentGateway REST API,
  # and returs the parsed response as hash.
  # === Parameters
  # * _method_ = method name, eg.: 'Init'
  # * _request_hash_ = request parameters as hash
  # === Example
  #  submit_request('Result', {'TransactionId' => '123456789abc'})
  def submit_request(method, request_hash)
    header_key = Base64.encode64(@@config[:store] + ':' + @@config[:api_key])
    response = RestClient.post(
      @@config[:header_host] + REST_API,
      { method: method, json: request_hash.to_json },
      accept: :json,
      Authorization: "Basic #{header_key}")
    JSON.load(response).to_hash
  end
end # class PaymentGateway

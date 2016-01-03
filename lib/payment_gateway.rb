require 'net/http'
require 'net/https'
require 'open-uri'
require 'rexml/document'
require 'cgi'
require 'logger'
require 'yaml'
require 'rest-client'

#module Payment

  class DefaultLogger

    attr_accessor :payment_method, :order_id, :payment_reference, :request, :response

    def initialize
      #self.payment_method= payment_method
    end

    def log(order_id, payment_reference, request, response)
      self.order_id          ||= order_id
      self.payment_reference ||= payment_reference
      self.request           ||= request
      self.response          ||= response

      puts self.inspect
    end

    def inspect_old
      res = " Payment_method #{self.payment_method}"
      res += ' OrderId: ' + self.order_id.to_s if self.order_id
      res += ' OrderId: ' unless self.order_id
      res += ' PaymentReference: ' + self.payment_reference.to_s if self.payment_reference
      res += ' PaymentReference: ' unless self.payment_reference
      res += ' Request: ' + self.request.to_s if self.request
      res += ' Request: ' unless self.request
      res += ' Response: ' + self.response.body.to_s if self.response
      res += ' Response: ' unless self.response

      return res
    end

  end # Default logger

  class PaymentGateway

    @@config = {
      :provider => 'OTP',
      :store => '',
      :currency => 'HUF',
      :language => 'HU',
      :response_mode => 'XML',
      :host => '',
      :header_host => 'test.paymentgateway.hu',
      :port => '',
      :use_ssl => 'true',
      :auto_commit_providers => ['MPP2'],
      :auto_commit_not_implemented => ['OTPayMP'],
      :app_host => ''
    }

    @@valid_config_keys = @@config.keys

    attr_accessor :provider

    # through hash
    def self.configure(opts = {})
      opts.each { |k,v| @@config[k.to_sym] = v if @@valid_config_keys.include?(k.to_sym) }
    end

    # through yaml file
    def self.configure_with(path_to_yaml_file)
      begin
        config = YAML::load(IO.read(path_to_yaml_file))
      rescue Errno::ENOENT
        log(:warning, "YAML configuration file couldn't be found. Using defaults."); return
      rescue Psych::SyntaxError
        log(:warning, "YAML configuration file contains invalid syntax. Using defaults."); return
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
    # PaymentGateway.
    # === Parameters
    # * _response_url_ = relative url to which PG shall redirect the user's browser after payment
    # * _amount_ = amount to charge the user
    # * _order_id_ = vendor-specific id of the order
    # * _user_id_ = id of the user
    # * _logger_ (optional) = logger to use (must implement <tt>log(v1,v2,v3,v4)</tt>)
    # === Example
    #  pg = PaymentGateway.new
    #  success, tr_id, result_hash = pg.init('deals/755-valami/product/1/verify_payment', 3000, '1234abc', '123ab')
    def init(response_url, amount, order_id, user_id, logger = DefaultLogger.new)
      logger.log(order_id, nil, nil, nil)

      resource_url = @@config[:host]
      init_hash = {
        'ProviderName' => provider,
        'StoreName'    => @@config[:store],
        'ResponseUrl'  => CGI::escape(@@config[:app_host] + response_url),
        'Amount'       => amount.to_s,
        'OrderId'      => order_id.to_s,
        'UserId'       => user_id.to_s,
        'Currency'     => @@config[:currency],
        'Language'     => @@config[:language],
        'ResponseMode' => @@config[:response_mode],
        'AutoCommit'   => (@@config[:auto_commit_providers].include?(provider).to_s if !@@config[:auto_commit_not_implemented].include?(provider))
      }

      logger.log(nil, nil, init_hash.to_json, nil)

      response = JSON.load(RestClient.post 'https://paymentgateway.hu/api/rest', {:method => 'Init', :json => init_hash.to_json})

      logger.log(nil, nil, nil, response.to_s)

      result = {
        'ResultCode' => response.to_hash['ResultCode'],
        'ResultMessage' => response.to_hash['ResultMessage'],
        'TransactionId' => response.to_hash.keys.include?('TransactionId') ? response.to_hash['TransactionId'] : ''
      }

      success = result['ResultCode'].to_s == 'SUCCESSFUL' ? true : false
      tr_id = result['TransactionId'].to_s if result['TransactionId'].to_s.size == 32

      logger.log(nil, tr_id, nil, nil)

      return success, tr_id, result

    rescue => e
      Logger.new(STDOUT).error e.message
      Logger.new(STDOUT).error e.backtrace
    end

    # The +start_payment+ instance method composes the url the user has to be redirected to.
    # === Parameters
    # * _order_id_ = Id of the order (optional, but will make your life easier)
    # * _transaction_id_ = PG transaction id, returned by init
    # === Example
    #  redirect_to pg.start_payment('123456789abc')
    def start_payment(order_id, transaction_id, logger = DefaultLogger.new)
      url = 'http://' + @@config[:header_host] + '/Start?TransactionId=' + transaction_id.to_s
      logger.log(order_id.to_i, transaction_id, url, nil)
      return url
    end

    # The +result+ instance method queries the status of the payment from PG
    # === Parameters
    # * _transaction_id_ = PG transaction id, returned by init
    # * _logger_ (optional) = logger to use (must implement <tt>log(v1,v2,v3,v4)</tt>)
    # === Example
    #  pg = PaymentGateway.new
    #  success, result_hash = pg.result('123456789abc')
    def result(transaction_id, logger = DefaultLogger.new)
      logger.log(nil, transaction_id, nil, nil)

      resource_url = @@config[:host]
      result_hash = {
        'TransactionId' => transaction_id.to_s
      }

      logger.log(nil, nil, result_hash.to_s, nil)

      response = JSON.load(RestClient.post 'https://paymentgateway.hu/api/rest', {:method => 'Result', :json => result_hash.to_json})

      logger.log(nil, nil, nil, response.to_s)

      response_hash = response.to_hash
      result = {
        'ResultCode' => response_hash['ResultCode'],
        'ResultMessage' => response_hash['ResultMessage']
      }

      result['TransactionId']         = response_hash['TransactionId'] ? response_hash['TransactionId'] : ''
      result['Anum']                  = response_hash['Anum'] ? response_hash['Anum'] : ''
      result['OrderId']               = response_hash['OrderId'] ? response_hash['OrderId'] : ''
      result['UserId']                = response_hash['UserId'] ? response_hash['UserId'] : ''
      result['ProviderTransactionId'] = response_hash['ProviderTransactionId'] ? response_hash['ProviderTransactionId'] : ''
      result['AutoCommit']            = response_hash['AutoCommit'] ? response_hash['AutoCommit'] : ''
      result['CommitState']           = response_hash['CommitState'] ? response_hash['CommitState'] : ''

      logger.log(result['OrderId'], nil, nil, nil)

      success = result['ResultCode'].to_s == 'SUCCESSFUL' ? true : false

      return success, result

    rescue => e
      Logger.new(STDOUT).error e.message
      Logger.new(STDOUT).error e.backtrace

    end

    # The +close+ instance method finalizes the payment in one of the following
    # ways: 1) cancel the authorization hold on the customer's credit or debit card,
    # or 2) submit the transaction and thus effectively charging the customer's
    # card.
    # === Parameters
    # * _transaction_id_ = PG transaction id, returned by init
    # * _approve_ (optional, boolean) = cancel, or submit
    # * _logger_ (optional) = logger to use (must implement <tt>log(v1,v2,v3,v4)</tt>
    # === Example
    #  PaymentGateway.new.close('1234hfajl', false)
    def close(transaction_id, approved = true, logger = DefaultLogger.new)
      logger.log(nil, transaction_id, nil, nil)

      http = Net::HTTP.new(@@config[:host], @@config[:port])
      http.use_ssl = @@config[:use_ssl]
      request_path = '/Close?'
      request_path += 'TransactionId=' + transaction_id.to_s + '&'
      request_path += 'Approved='      + approved.to_s
      request = Net::HTTP::Get.new(request_path)
      request.add_field "Host", @@config[:header_host]

      logger.log(nil, nil, request_path, nil)

      response = http.start {|h| h.request(request) }

      logger.log(nil, nil, nil, response)

      doc = REXML::Document.new(response.body)

      result = {
        'ResultCode' => REXML::XPath.first(doc, "//ResultCode").text
      }

      result['TransactionId'] = REXML::XPath.first(doc, "//TransactionId") ? REXML::XPath.first(doc, "//TransactionId").text : ''

      success = result['ResultCode'].to_s == 'SUCCESSFUL' ? true : false
      tr_id = result['TransactionId'].to_s if result['TransactionId'].to_s.size == 32

      logger.log(nil, tr_id, nil, nil)

      return success, result

    rescue => e
      Logger.new(STDOUT).error e.message
      Logger.new(STDOUT).error e.backtrace

    end

  end # class PaymentGateway

#end

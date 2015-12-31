require 'net/http'
require 'net/https'
require 'open-uri'
require 'rexml/document'
require 'cgi'
require 'logger'
require 'yaml'

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

    def inspect
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

      http = Net::HTTP.new(@@config[:host], @@config[:port])
      http.use_ssl = @@config[:use_ssl]
      request_path = '/Init?'
      request_path += 'ProviderName=' + provider + '&'
      request_path += 'StoreName='    + @@config[:store] + '&'
      request_path += 'ResponseUrl='  + CGI::escape(@@config[:app_host] + response_url) + '&'
      request_path += 'Amount='       + amount.to_s + '&'
      request_path += 'OrderId='      + order_id.to_s + '&'
      request_path += 'UserId='       + user_id.to_s + '&'
      request_path += 'Currency='     + @@config[:currency] + '&'
      request_path += 'Language='     + @@config[:language] + '&'
      request_path += 'ResponseMode=' + @@config[:response_mode] + '&'
      request_path += 'AutoCommit='   + @@config[:auto_commit_providers].include?(provider).to_s if !@@config[:auto_commit_not_implemented].include?(provider)
      request = Net::HTTP::Get.new(request_path)
      request.add_field "Host", @@config[:header_host]

      logger.log(nil, nil, request_path, nil)

      response = http.start {|h| h.request(request) }

      logger.log(nil, nil, nil, response)

      doc = REXML::Document.new(response.body)

      result = {
        'ResultCode' => REXML::XPath.first(doc, "//ResultCode").text,
        'ResultMessage' => REXML::XPath.first(doc, "//ResultMessage").text
      }

      result['TransactionId'] = REXML::XPath.first(doc, "//TransactionId") ? REXML::XPath.first(doc, "//TransactionId").text : ''

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

      http = Net::HTTP.new(@@config[:host], @@config[:port])
      http.use_ssl = @@config[:use_ssl]
      request_path = '/Result?'
      request_path += 'TransactionId=' + transaction_id.to_s
      request = Net::HTTP::Get.new(request_path)
      request.add_field "Host", @@config[:header_host]

      logger.log(nil, nil, request_path, nil)

      response = http.start {|h| h.request(request) }

      logger.log(nil, nil, nil, response)

      doc = REXML::Document.new(response.body)

      result = {
        'ResultCode' => REXML::XPath.first(doc, "//ResultCode").text,
        'ResultMessage' => REXML::XPath.first(doc, "//ResultMessage").text
      }
      result['TransactionId']         = REXML::XPath.first(doc, "//TransactionId") ? REXML::XPath.first(doc, "//TransactionId").text : ''
      result['Anum']                  = REXML::XPath.first(doc, "//Anum") ? REXML::XPath.first(doc, "//Anum").text : ''
      result['OrderId']               = REXML::XPath.first(doc, "//OrderId") ? REXML::XPath.first(doc, "//OrderId").text : ''
      result['UserId']                = REXML::XPath.first(doc, "//UserId") ? REXML::XPath.first(doc, "//UserId").text : ''
      result['ProviderTransactionId'] = REXML::XPath.first(doc, "//ProviderTransactionId") ? REXML::XPath.first(doc, "//ProviderTransactionId").text : ''
      result['AutoCommit']            = REXML::XPath.first(doc, "//AutoCommit") ? REXML::XPath.first(doc, "//AutoCommit").text : ''
      result['CommitState']           = REXML::XPath.first(doc, "//CommitState") ? REXML::XPath.first(doc, "//CommitState").text : ''

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

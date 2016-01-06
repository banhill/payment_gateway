describe PaymentGateway do
  describe "#configure" do
    it "loads a legal set of config parameters as hash" do
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
      expect(PaymentGateway.config).to eq(conf_hash)
    end

    it "refuses to load a configuration with illegal attributes" do
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
      expect(PaymentGateway.config).not_to eq(conf_hash)
    end

    it "loads a legal configuration file" do
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
      PaymentGateway.configure_with('spec/valid_test_config.yml')
      expect(PaymentGateway.config).to eq(conf_hash)
    end
  end

  describe "#start" do
    it "produces the correct url to redirect the user to" do
      PaymentGateway.configure({:header_host => 'my.fake.host'})
      pg = PaymentGateway.new
      pg.transaction_id = 'tr_id_123'
      #pg.order_id = 'order_id_123'
      expect(pg.start).to eq('http://my.fake.host/Start?TransactionId=tr_id_123')
    end
  end

  describe "#sinatra_test" do
    it "makes sure the sinatra app is up and running" do
      uri = URI('https://paymentgateway.hu/valami')

      response = JSON.load(Net::HTTP.get(uri))
      expect(response['TransactionId']).to eq '6ef7bc3755ac699c3d56db49711f6d1f'
    end
  end

  describe "#init" do
    it "initializes the payment interface, gets a transaction id" do
      conf_hash = {
        :provider => 'PayPal',
        :store => 'PhantomStore',
        :currency => 'USD',
        :language => 'EN',
        :response_mode => 'XML',
        :host => 'paymentgateway.hu',
        :header_host => 'paymentgateway.hu',
        :port => '3333',
        :use_ssl => 'true',
        :auto_commit_providers => ['MPP2'],
        :auto_commit_not_implemented => ['OTPayMP'],
        :app_host => 'localhost'
      }
      PaymentGateway.configure(conf_hash)
      pg = PaymentGateway.new
      pg.response_url = "payment/gateway/response/url"
	    pg.amount = 3000
	    pg.currency = "HUF"
	    pg.order_id = "order123"
	    pg.user_id = "user123"
	    pg.language = "HU"
      response = pg.init
      expect(response).to eq({"ResultCode"=>"SUCCESSFUL", "ResultMessage"=>nil, "TransactionId"=>"6ef7bc3755ac699c3d56db49711f6d1f"})
    end
  end

  describe "#result" do
    it "queries the state of the transaction, gets pending response" do
      conf_hash = {
        :provider => 'PayPal',
        :store => 'PhantomStore',
        :currency => 'USD',
        :language => 'EN',
        :response_mode => 'XML',
        :host => 'paymentgateway.hu',
        :header_host => 'paymentgateway.hu',
        :port => '3333',
        :use_ssl => 'true',
        :auto_commit_providers => ['MPP2'],
        :auto_commit_not_implemented => ['OTPayMP'],
        :app_host => 'localhost'
      }

      expected_result_hash = {
        "TransactionId" => "6ef7bc3755ac699c3d56db49711f6d1f",
        "ResultCode" => "PENDING",
        "ResultMessage" => "M\u00e9g nincs eredm\u00e9ny",
        "Anum" => nil,
        "OrderId" => "order123",
        "UserId" => "user123",
        "ProviderTransactionId" => "6281422198151381",
        "AutoCommit" => "true",
        "CommitState" => "APPROVED"
      }
      PaymentGateway.configure(conf_hash)
      pg = PaymentGateway.new
      pg.transaction_id = '6ef7bc3755ac699c3d56db49711f6d1f'
      response = PaymentGateway.new.result
      expect(response).to eq(expected_result_hash)
    end
  end

  describe "#close" do
    it "it closes the transaction with approved state" do
      conf_hash = {
        :provider => 'PayPal',
        :store => 'PhantomStore',
        :currency => 'USD',
        :language => 'EN',
        :response_mode => 'XML',
        :host => 'paymentgateway.hu',
        :header_host => 'paymentgateway.hu',
        :port => '3333',
        :use_ssl => 'true',
        :auto_commit_providers => ['MPP2'],
        :auto_commit_not_implemented => ['OTPayMP'],
        :app_host => 'localhost'
      }

      expected_result_hash = {
        'TransactionId' => '',
        'ResultCode' => 'OtpResponseCodeError',
        'ResultMessage' => "Hib\u00e1s v\u00e1lasz \u00e9rkezett az OTP Bank szerver\u00e9t\u0151l (NINCSILYENFIZETESIFOLYAMAT)"
      }

      PaymentGateway.configure(conf_hash)
      pg = PaymentGateway.new
      pg.transaction_id = '6ef7bc3755ac699c3d56db49711f6d1f'
      pg.approved = 'true'
      response = pg.close
      expect(response).to eq(expected_result_hash)
    end
  end
end

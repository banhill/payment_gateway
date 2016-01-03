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

  describe "#start_payment" do
    it "produces the correct url to redirect the user to" do
      PaymentGateway.configure({:header_host => 'my.fake.host'})
      expect(PaymentGateway.new.start_payment('order_id_123', 'tr_id_123')).to eq('http://my.fake.host/Start?TransactionId=tr_id_123')
    end
  end

  describe "#sintra_test" do
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
      success, tr_id, result_hash = PaymentGateway.new.init('deals/755-valami/product/1/verify_payment', 3000, '1234abc', '123ab')
      expect(success).to be(true)
      expect(tr_id).to eq('6ef7bc3755ac699c3d56db49711f6d1f')
      expect(result_hash).to eq({"ResultCode"=>"SUCCESSFUL", "ResultMessage"=>nil, "TransactionId"=>"6ef7bc3755ac699c3d56db49711f6d1f"})
    end
  end

  describe "#result" do
    pending
  end

  describe "#close" do
    pending
  end
end

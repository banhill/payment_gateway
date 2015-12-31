# based on: https://robots.thoughtbot.com/how-to-stub-external-services-in-tests
require 'sinatra/base'

class FakePaymentGateway < Sinatra::Base
  post '/init' do
    json_response 200, 'init.json'
  end

  post '/result' do
    json_response 200, result.json
  end

  post '/close' do
    json_response 200, close.json
  end

  private

  def json_response(response_code, file_name)
    content_type :json
    status response_code
    File.open(File.dirname(__FILE__) + '/fixtures/' + file_name, 'rb').read
  end
end

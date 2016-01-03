# based on: https://robots.thoughtbot.com/how-to-stub-external-services-in-tests
require 'sinatra/base'

class FakePaymentGateway < Sinatra::Base
  get '/valami' do
    json_response 200, 'init.json'
  end

  post '/api/rest/?' do
    method = params[:method]
    json = params[:json]

    case method
    when 'Init'
      json_response 200, 'init.json'
    when 'Result'
      json_response 200, 'result.json'
    when 'Close'
      json_response 200, 'close.json'
    else
      json_response 500, nil
    end
  end

  private

  def json_response(response_code, file_name)
    content_type :json
    status response_code
    File.open(File.dirname(__FILE__) + '/../fixtures/' + file_name, 'rb').read
  end
end

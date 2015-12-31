Gem::Specification.new do |s|
  s.name        = 'payment_gateway'
  s.version     = '0.0.0'
  s.date        = '2015-12-26'
  s.summary     = "Gem for Bigfish's PaymentGateway service"
  s.description = "Use BigFish's payment methods in your ruby project."
  s.authors     = ["Gábor BÁNHEGYESI"]
  s.email       = 'banhill@gmail.com'
  s.files       = ["lib/payment_gateway.rb"]
  s.license     = 'MIT'
  s.add_development_dependency "rspec"
  s.add_development_dependency "webmock"
  s.add_development_dependency "sinatra"
end

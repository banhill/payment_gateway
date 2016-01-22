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
  s.add_development_dependency "rspec", "~> 3.4", ">= 3.4.0"
  s.add_development_dependency "webmock", "~> 1.22", ">= 1.22.3"
  s.add_development_dependency "sinatra", "~> 1.4.0", ">= 1.4.6"
  s.add_runtime_dependency "rest-client", "= 1.6.9"
end

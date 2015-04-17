require 'json'
require 'date'
require 'bundler'
Bundler.require
$stdout.sync = true

redis = Redis.new(url: ENV['REDISTOGO_URL'])
codes = JSON.parse(redis.get('codes') || '[]').map do |code|
  { code: code['code'], expires: DateTime.parse(code['expires']) }
end

before do
  codes.reject! do |code|
    code[:expires] < DateTime.now
  end
end

after do
  redis.set('codes', codes.to_json)
end

get '/' do
  Twilio::TwiML::Response.new do |r|
    r.Gather numDigits: 4, action: '/access', timeout: 3 do |g|
      g.Say 'Enter access code, or press star to call the office.'
    end
    r.Say 'Code not entered, disconnecting.'
  end.text
end

post '/access' do
  Twilio::TwiML::Response.new do |r|
    if codes.any?{ |code| code[:code] == params['Digits'] }
      r.Say 'Access granted.'
      r.Play digits: '5ww5ww5ww5'
    elsif params['Digits'] == '*'
      r.Dial ENV['OFFICE_PHONE_NUMBER']
    else
      r.Say 'Access denied.'
    end
  end.text
end

post '/generate' do
  if params['token'] == ENV['SLASH_COMMAND_TOKEN']
    new_code = rand(10000).to_s.rjust(4, '0') until codes.none?{ |code| code[:code] == new_code }
    codes.push({ code: new_code, expires: Chronic.parse('5 minutes from now') })
    "Generated new access code #{new_code}, expires #{codes.last[:expires]}"
  end
end

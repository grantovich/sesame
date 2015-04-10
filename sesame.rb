require 'bundler'
Bundler.require

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
    if params['Digits'] == '1138'
      r.Say 'Access granted.'
      r.Play digits: '5ww5ww5ww5'
    elsif params['Digits'] == '*'
      r.Dial '+16178070857'
    else
      r.Say 'Access denied.'
    end
  end.text
end

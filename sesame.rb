require 'json'
require 'bundler'
Bundler.require

require_relative 'lib/code'
require_relative 'lib/command'
require_relative 'lib/slack'

# FIXME: This whole storage system only works with a single app instance
redis = Redis.new(url: ENV['REDIS_URL'])
Codes = JSON.parse(redis.get('codes') || '[]').map{ |code_attrs| Code.new(code_attrs) }

before do
  Codes.reject!(&:expired?)
end

after do
  redis.set('codes', Codes.to_json)
end

get '/' do
  Twilio::TwiML::Response.new do |r|
    r.Gather numDigits: 4, action: '/access' do |g|
      g.Say 'Enter access code, or press star to call the office.'
    end
    r.Say 'Code not entered. Goodbye.'
  end.text
end

post '/access' do
  Twilio::TwiML::Response.new do |r|
    if params['Digits'] == '*'
      r.Dial ENV['OFFICE_PHONE_NUMBER']
    else
      found_code = Codes.find{ |code| code.digits == params['Digits'] }

      if found_code.try(:valid?)
        r.Say 'Access granted.'
        r.Play digits: '5ww5ww5ww5ww5'
        Slack.public_message("Access code used: #{found_code}")
      else
        r.Say 'Invalid access code.'
        r.Redirect '/', method: 'GET'

        if found_code.present?
          Slack.public_message("Not-yet-valid access code entered: #{found_code}")
        else
          Slack.public_message("Invalid access code entered: #{params['Digits']}")
        end
      end
    end
  end.text
end

post '/command' do
  return status 401 unless params['token'] == ENV['SLASH_COMMAND_TOKEN']

  command = Command.new(params['text'], params['user_name'])
  Slack.private_message(params['user_name'], "> _#{command}_\n" + command.response)

  status 204
end

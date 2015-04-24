require 'json'
require 'bundler'
Bundler.require

class AccessCode
  include ActiveAttr::Model

  attribute :digits, type: String
  attribute :label, type: String
  attribute :creator, type: String
  attribute :begins_at, type: DateTime
  attribute :expires_at, type: DateTime

  def valid?
    begins_at < DateTime.now && !expired?
  end

  def expired?
    expires_at < DateTime.now
  end

  def to_s
    [
      digits,
      "Begins #{format_time(begins_at)}",
      "Expires #{format_time(expires_at)}",
      "Created by #{creator}",
      label || '(no label)'
    ].join(' – ')
  end

  private

  def format_time(time)
    time.to_time.getlocal.strftime('%Y-%m-%d at %I:%M%P')
  end
end

class Slack
  def self.public_message(text)
    self.post_message(text: text)
  end

  def self.private_message(user_name, text)
    self.post_message(text: text, channel: '@' + user_name)
  end

  def self.post_message(params)
    HTTParty.post(ENV['WEBHOOK_URL'], body: params.to_json)
  end
end

# FIXME: This whole storage system only works with a single app instance
redis = Redis.new(url: ENV['REDISTOGO_URL'])
codes = JSON.parse(redis.get('codes') || '[]').map{ |code_attrs| AccessCode.new(code_attrs) }

before do
  codes.reject!(&:expired?)
end

after do
  redis.set('codes', codes.to_json)
end

get '/' do
  Twilio::TwiML::Response.new do |r|
    r.Gather numDigits: 4, action: '/access', timeout: 3 do |g|
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
      code = codes.find{ |code| code.digits == params['Digits'] }

      if code.try(:valid?)
        r.Say 'Access granted.'
        r.Play digits: '5ww5ww5ww5ww5'
        Slack.public_message("Access code used: #{code}")
      else
        r.Say 'Invalid access code. Goodbye.'

        if code.present?
          Slack.public_message("Not-yet-valid access code entered: #{code}")
        else
          Slack.public_message("Invalid access code entered: #{params['Digits']}")
        end
      end
    end
  end.text
end

post '/command' do
  return status 401 unless params['token'] == ENV['SLASH_COMMAND_TOKEN']

  command = params['text'].strip.presence || '(no command)'

  response = case command
  when /^list/

    if codes.any?
      codes.map(&:to_s).join("\n")
    else
      'There are no active access codes right now.'
    end

  when /^create/

    begins = Chronic.parse(command[/starting (.*)( ending| for|$)/, 1]) || Time.now
    expires = Chronic.parse(command[/ending (.*)( starting| for|$)/, 1]) || begins + 15.minutes
    label = command[/for (.*)( starting| ending|$)/, 1]

    new_digits = loop do
      random_digits = rand(10000).to_s.rjust(4, '0')
      break random_digits unless codes.any?{ |code| code.digits == random_digits }
    end

    code = AccessCode.new(
      digits: new_digits,
      begins_at: begins,
      expires_at: expires,
      creator: params['user_name'],
      label: label
    )
    codes.push(code)

    "Generated access code: #{code}"

  when /^revoke/

    digits = command[/revoke (\d{4})/, 1]

    if codes.reject!{ |code| code.digits == digits }
      "Access code #{digits} has been revoked."
    else
      "Error: Access code #{digits} does not exist."
    end

  else

    [
      'List current access codes: /sesame list',
      'Create new access code: /sesame create [starting <datetime>] [ending <datetime>] [for <label>]',
      'Revoke existing access code: /sesame revoke <code>',
      '_ Many plain-English time formats are understood, see https://github.com/mojombo/chronic#examples _'
    ].join("\n")

  end

  Slack.private_message(params['user_name'], '> _' + command + "_\n" + response)
  status 204
end

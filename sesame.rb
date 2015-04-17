require 'json'
require 'bundler'
Bundler.require
TIME_FORMAT = '%Y-%m-%d at %I:%M%P'

redis = Redis.new(url: ENV['REDISTOGO_URL'])
codes = JSON.parse(redis.get('codes') || '[]').map do |code|
  {
    code: code['code'],
    begins: Time.parse(code['begins']),
    expires: Time.parse(code['expires']),
    creator: code['creator'],
    label: code['label']
  }
end

before do
  codes.reject! do |code|
    code[:expires] < Time.now
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
    if codes.any?{ |code| code[:code] == params['Digits'] && code[:begins] < Time.now }
      r.Say 'Access granted.'
      r.Play digits: '5ww5ww5ww5'
    elsif params['Digits'] == '*'
      r.Dial ENV['OFFICE_PHONE_NUMBER']
    else
      r.Say 'Access denied.'
    end
  end.text
end

post '/command' do
  return status 401 unless params['token'] == ENV['SLASH_COMMAND_TOKEN']
  command = params['text'] || ''

  if command.strip == 'list'

    codes.map do |code|
      [
        code[:code],
        "Begins #{code[:begins].strftime(TIME_FORMAT)}",
        "Expires #{code[:expires].strftime(TIME_FORMAT)}",
        "Created by #{code[:creator]}",
        code[:label] || '(no label)'
      ].join(' – ')
    end.join("\n")

  elsif command =~ /begins|expires|for/

    begins = Chronic.parse(command[/begins (.*)( expires| for|$)/, 1]) || Time.now
    expires = Chronic.parse(command[/expires (.*)( for|$)/, 1]) || begins + (15 * 60)
    label = command[/for (.*)/, 1]

    new_code = loop do
      random_code = rand(10000).to_s.rjust(4, '0')
      break random_code unless codes.any?{ |code| code[:code] == random_code }
    end

    codes.push({
      code: new_code,
      begins: begins,
      expires: expires,
      creator: params['user_name'],
      label: label
    })

    "Generated access code #{new_code}, begins #{begins.strftime(TIME_FORMAT)}, expires #{expires.strftime(TIME_FORMAT)}"

  elsif command.strip =~ /^revoke \d{4}$/

    target_code = command[/revoke (\d{4})/, 1]
    if codes.reject!{ |code| code[:code] == target_code }
      "Access code #{target_code} has been revoked."
    else
      "Error: Access code #{target_code} does not exist."
    end

  else
    [
      'List current access codes: /sesame list',
      'Generate new access code: /sesame [begins <datetime>] [expires <datetime>] [for <label>]',
      'Revoke existing access code: /sesame revoke <code>'
    ].join("\n")
  end
end

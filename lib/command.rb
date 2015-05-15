class Command
  COMMANDS = [:list, :create, :revoke]

  attr_reader :command
  def initialize(input, username)
    @input = input
    @username = username
    @command = input.strip[/^\S+/].try(:downcase).try(:to_sym)
    @params = input.strip[/\s(.*)/, 1] || ''
  end

  def to_s
    @input.presence || '(no command)'
  end

  def response
    if COMMANDS.include?(@command)
      send(@command)
    else
      [
        'List current access codes: /sesame list',
        'Create new access code: /sesame create [starting <datetime>] [ending <datetime>] [for <label>]',
        'Revoke existing access code: /sesame revoke <code>',
        '_ Many plain-English time formats are understood, see https://github.com/mojombo/chronic#examples _'
      ].join("\n")
    end
  end

  private

  def list
    if Codes.any?
      Codes.map(&:to_s).join("\n")
    else
      'There are no active access codes right now.'
    end
  end

  def create
    begins = Chronic.parse(@params[/starting (.*?)( ending| for|$)/, 1]) || Time.now
    expires = Chronic.parse(@params[/ending (.*?)( starting| for|$)/, 1]) || begins + 15.minutes
    label = @params[/for (.*?)( starting| ending|$)/, 1]

    new_digits = loop do
      random_digits = rand(10000).to_s.rjust(4, '0')
      break random_digits unless Codes.any?{ |code| code.digits == random_digits }
    end

    code = Code.new(
      digits: new_digits,
      begins_at: begins,
      expires_at: expires,
      creator: @username,
      label: label
    )
    Codes.push(code)

    "Generated access code: #{code}"
  end

  def revoke
    digits = @params[/\d{4}/]

    if Codes.reject!{ |code| code.digits == digits }
      "Access code #{digits} has been revoked."
    else
      "Error: Access code #{digits} does not exist."
    end
  end
end

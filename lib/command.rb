class Command
  COMMANDS = [:list, :create, :revoke]

  attr_reader :command
  def initialize(input, username)
    @input = input
    @username = username
    @command = input.strip[/^\S+/]&.downcase&.to_sym
    @params = input.strip[/\s(.*)/, 1] || ''
  end

  def to_s
    @input.presence || '(no command)'
  end

  def response
    if COMMANDS.include?(@command)
      send(@command)
    else
      <<~USAGE
        *Basic Usage*
        `/sesame list` – List all known access codes
        `/sesame create` – Create an access code that expires in 15 minutes
        `/sesame revoke 1234` – Immediately expire access code 1234

        *Customization*
        `/sesame create ending in 2 hours` – Customize expiration time
        `/sesame create ending today at 5:30pm` – Expire at a specific time
        `/sesame create starting Wednesday at 9am, ending 5/18 at 5pm` – Become valid at a specific time
        `/sesame create starting 6pm, ending 9pm, for Boston CSS meetup` – Label the code so people know what it's for
        _ Start time, end time, and label are all optional. Recognized time formats: https://github.com/mojombo/chronic#examples _
      USAGE
    end
  end

  private

  def list
    if Codes.any?
      Codes.map(&:to_s).join("\n")
    else
      'There are no access codes right now.'
    end
  end

  def create
    begins = Chronic.parse(@params[/starting (.*?)( ending| for|$)/, 1]) || Time.now
    expires = Chronic.parse(@params[/ending (.*?)( starting| for|$)/, 1]) || begins + 15.minutes
    label = @params[/for (.*?)( starting| ending|$)/, 1]

    new_digits = loop do
      random_digits = rand(10_000).to_s.rjust(4, '0')
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

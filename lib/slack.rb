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

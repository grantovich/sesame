class Code
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

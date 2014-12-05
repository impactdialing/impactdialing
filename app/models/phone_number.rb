class PhoneNumber
  def initialize(number)
    @number = PhoneNumber::sanitize(number.to_s)
  end

  def valid?
    (not @number.blank?) and
    (@number.length >= 10) and
    (@number.length <= 16) and
    has_only_digits?
  end

  def to_s
    @number
  end

  private
  def self.sanitize(number)
    number.scan(/\d/).join
  end

  def has_only_digits?
    (not @number.match(/[^\d]+/))
  end
end
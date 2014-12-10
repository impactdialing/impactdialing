class PhoneNumber
  def initialize(number)
    @number = PhoneNumber::sanitize(number)
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

  def self.sanitize(number)
    number.to_s.scan(/\d/).join
  end

  def self.valid?(number)
    new(number).valid?
  end

  def has_only_digits?
    (not @number.match(/[^\d]+/))
  end
end
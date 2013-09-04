module ExceptionMethods
  class SpecialCeption < ArgumentError; end

  def fake_exception
    msg = 'There be errors!'

    begin
      raise SpecialCeption, msg
    rescue SpecialCeption => e
      return e
    end
  end
end
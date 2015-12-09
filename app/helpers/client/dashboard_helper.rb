module Client::DashboardHelper
  JSON_ESCAPE = { '&' => '\u0026', '>' => '\u003e', '<' => '\u003c', "\u2028" => '\u2028', "\u2029" => '\u2029' }
  JSON_ESCAPE_REGEXP = /[\u2028\u2029&><]/u

  def json_escape_41(s)
    result = s.to_s.gsub(JSON_ESCAPE_REGEXP, JSON_ESCAPE)
    s.html_safe? ? result.html_safe : result
  end
end

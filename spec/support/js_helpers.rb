module JSHelpers
  def blur(selector)
    page.execute_script("$('#{selector}').blur();")
  end
end
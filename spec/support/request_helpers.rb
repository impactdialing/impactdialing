module RequestHelpers
  def encode_uri(str)
    URI.encode_www_form_component(str)
  end
end
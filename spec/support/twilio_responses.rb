module TwilioResponses
  def root_path
    File.join(Rails.root, 'spec', 'fixtures', 'twilio_responses')
  end

  def read_file(name)
    path = File.join(root_path, name)
    File.read(path)
  end

  def conference_by_name_response
    read_file('conference_by_name.xml')
  end

  def conference_list_response
    read_file('conference_list.xml')
  end

  def new_call_response
    read_file('new_call.xml')
  end

  def updated_call_response
    read_file('updated_call.xml')
  end

  def muted_participant_response
    read_file('muted_participant.xml')
  end
end
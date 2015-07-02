class VoterListRender < MailerRendering
  def completed(content_type, results)
    @results = results
    opts     = {
      template: "voter_list_mailer/completed.#{content_type}",
      format: content_type
    }
    render(opts)
  end

  def failed(content_type, errors)
    @errors = errors
    opts = {
      template: "voter_list_mailer/failed.#{content_type}",
      format: content_type
    }
    render(opts)
  end
end

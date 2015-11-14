class VoterListRender < MailerRendering
  def completed(content_type, results)
    @results = results
    opts     = {
      template: "voter_list_mailer/completed.#{content_type}",
      format: content_type
    }
    render(opts)
  end

  def pruned_numbers(content_type, results)
    @results = results
    opts     = {
      template: "voter_list_mailer/pruned_numbers.#{content_type}",
      format: content_type
    }
    render(opts)
  end

  def pruned_leads(content_type, results)
    @results = results
    opts     = {
      template: "voter_list_mailer/pruned_leads.#{content_type}",
      format: content_type
    }
    render(opts)
  end
end

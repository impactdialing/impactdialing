class Report::DialsController < Ruport::Controller

  stage :overview

  required_option :campaign

  def setup
    self.data = Dials::CampaignSummary.new(options).make
  end

  class HTML < Ruport::Formatter::HTML

    renders :html, :for => Report::DialsController

    build :overview do
      markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
      output << markdown.render("## Overview")
      output << markdown.render("The data in the overview table gives the current state of the campaign.")
      output << data.to_html(style: :justified)
    end
  end
end

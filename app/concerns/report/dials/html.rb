##
class Report::Dials::Html < Ruport::Formatter::HTML

  renders :html, :for => [Report::Dials::SummaryController, Report::Dials::ByStatusController]

private
  def markdown
    @markdown ||= Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  end

public
  build :heading do
    if options['heading']
      output << markdown.render("## #{options['heading']}")
    end
  end

  build :description do
    if options['description']
      output << markdown.render(options['description'])
    end
  end

  build :table do
    output << data.to_html(style: :justified)
  end
end

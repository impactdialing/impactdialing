##
class Report::Formatters::Html < Ruport::Formatter::HTML

  renders :html, :for => [
    Report::Dials::SummaryController, Report::Dials::ByStatusController,
    Report::Performance::VelocityController, Ruport::Controller::Table,
    Report::Dials::PassesController
  ]

private
  def markdown
    @markdown ||= Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  end

  def build_row(data)
    style = "font-weight: bold;"
    style = "padding-left: 10px;" if data.first =~ /»/
    output << "\t\t<tr>\n\t\t\t<td style=\"#{style}\">" +
              data.to_a.join("</td>\n\t\t\t<td>") +
              "</td>\n\t\t</tr>\n"
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

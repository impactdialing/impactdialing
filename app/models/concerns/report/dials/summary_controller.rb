##
class Report::Dials::SummaryController < Ruport::Controller
  # hack
  Report::Formatters::Html # ? formatters aren't loading => aren't declaring themselves to controllers

  stage :table

  required_option :campaign

public
  def setup
    self.data = Report::Dials::Summary.new(options).make
  end
end

##
class Report::Dials::ByStatusController < Ruport::Controller
  # hack
  Report::Dials::Html # ? formatters aren't loading => aren't declaring themselves to controllers

  stage :heading, :description, :table

  required_option :campaign, :heading, :description, :scoped_to

public
  def setup
    self.data = Report::Dials::ByStatus.new(options).make
  end
end


##
class Report::Dials::PassesController < Ruport::Controller
  # hack
  Report::Formatters::Html # ? formatters aren't loading => aren't declaring themselves to controllers

  stage :heading, :description, :table

  required_option :campaign

public
  def setup
    self.data = Report::Dials::Passes.new(options).make
  end
end

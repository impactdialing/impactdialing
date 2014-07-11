##
class Report::Performance::VelocityController < Ruport::Controller
  # hack
  Report::Formatters::Html # ? formatters aren't loading => aren't declaring themselves to controllers

  stage :description, :table

  required_option :record, :description

public
  def setup
    self.data = Report::Performance::Velocity.new(options).make
  end
end

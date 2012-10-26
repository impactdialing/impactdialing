require "spec_helper"

describe AdminReportJob do
  it "should create report based on string dates" do
    from = (Time.now - 1.week).to_date.to_s
    to = (Time.now).to_date.to_s
    expect { AdminReportJob.perform(from, to) }.to_not raise_error
  end
end

require "spec_helper"

describe AdminReportJob do
  let(:billable_minutes){ double }
  let(:report){ double({build: true}) }
  let(:from){ (Time.now - 1.week).to_date.to_s }
  let(:to){ (Time.now).to_date.to_s }

  before do
    Reports::BillableMinutes.stub(:new){ billable_minutes }
    Reports::Admin::EnterpriseByAccount.stub(:new){ report }
  end

  after do
    AdminReportJob.perform(from, to, 'Enterprise')
  end

  it 'instantiates a Reports::BillableMinutes obj with start & end dates' do
    Reports::BillableMinutes.should_receive(:new).
      with(Time.zone.parse(from).utc.beginning_of_day, Time.zone.parse(to).utc.end_of_day).
      and_return(billable_minutes)
  end

  it 'instantiates a Reports::Admin::EnterpriseByAccount obj' do
    report.should_receive(:build)

    Reports::Admin::EnterpriseByAccount.should_receive(:new).
      with(billable_minutes).
      and_return(report)
  end
end

require 'rails_helper'

describe AdminReportJob, reports: true do
  let(:billable_minutes){ double }
  let(:report){ double({build: true}) }
  let(:from){ (Time.now.beginning_of_month).to_date }
  let(:to){ (Time.now).to_date }
  let(:time_zone){ ActiveSupport::TimeZone.new("Pacific Time (US & Canada)") }
  let(:from_date){ from.strftime('%m/%d/%Y') }
  let(:to_date){ to.strftime('%m/%d/%Y') }

  before do
    allow(Reports::BillableMinutes).to receive(:new){ billable_minutes }
    allow(Reports::Admin::EnterpriseByAccount).to receive(:new){ report }
  end

  it 'instantiates a Reports::BillableMinutes obj with start & end dates' do
    month, day, year = from_date.split('/')
    expected_from    = Time.new(year, month, day, 12, 0, 0, time_zone.now.formatted_offset).beginning_of_day.utc
    month, day, year = to_date.split('/')
    expected_to      = Time.new(year, month, day, 12, 0, 0, time_zone.now.formatted_offset).end_of_day.utc

    expect(Reports::BillableMinutes).to receive(:new).
      with(expected_from, expected_to).
      and_return(billable_minutes)
    AdminReportJob.perform(from_date, to_date, 'Enterprise', nil)
  end

  it 'instantiates a Reports::Admin::EnterpriseByAccount obj' do
    expect(report).to receive(:build)

    expect(Reports::Admin::EnterpriseByAccount).to receive(:new).
      with(billable_minutes).
      and_return(report)
    AdminReportJob.perform(from_date, to_date, 'Enterprise', nil)
  end

  it 'requeues itself on TERM' do
    allow(Reports::BillableMinutes).to receive(:new){ raise Resque::TermException, 'TERM' }
    AdminReportJob.perform(from_date, to_date, 'Enterprise', nil)
    expect(resque_jobs(:reports)).to include({
      'class' => 'AdminReportJob',
      'args' => [from_date, to_date, 'Enterprise', nil]
    })
  end
end

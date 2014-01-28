require 'spec_helper'

describe AccountUsageRender do
  let(:values) do
    [23,46,58]
  end
  let(:billable_totals) do
    {
      1 => values.first,
      2 => values.second,
      3 => values.third
    }
  end
  let(:grand_total) do
    values.inject(:+)
  end

  before do
    @controller = AccountUsageRender.new
  end

  describe '#by_campaigns(content_type, billable_totals, grand_total, campaigns)' do
    let(:campaigns) do
      [
        double('Campaign 1', {
          id: 1,
          name: 'Campaign 1'
        }),
        double('Campaign 2', {
          id: 2,
          name: 'Campaign 2'
        }),
        double('Campaign 3', {
          id: 3,
          name: 'Campaign 3'
        })
      ]
    end

    context 'content_type = ":html"' do
      before do
        @template = @controller.by_campaigns(:html, billable_totals, grand_total, campaigns)
      end
      it 'renders the html template to a string: views/account_usage_mailer/by_campaigns' do
        t = @template.to_s

        t.should =~ /<h1.*>Account usage by campaign<\/h1>/
        t.should =~ /<th.*>Campaign<\/th>/
        t.should =~ /<th.*>Billable minutes<\/th>/

        t.should =~ /<td.*>Campaign 1<\/td>/
        t.should =~ /<td.*>#{values.first}<\/td>/

        t.should =~ /<td.*>Campaign 2<\/td>/
        t.should =~ /<td.*>#{values.second}<\/td>/

        t.should =~ /<td.*>Campaign 3<\/td>/
        t.should =~ /<td.*>#{values.third}<\/td>/
      end
    end

    context 'content_type = :text' do
      before do
        @template = @controller.by_campaigns(:text, billable_totals, grand_total, campaigns)
      end

      it 'renders the text template to a string: views/account_usage_mailer/by_campaigns' do
        t = @template.to_s

        t.should_not =~ /<\w+>/
        t.should =~ /Account usage by campaign/
        t.should =~ /Campaign/
        t.should =~ /Billable minutes/

        t.should =~ /Campaign 1/
        t.should =~ /#{values.first}/

        t.should =~ /Campaign 2/
        t.should =~ /#{values.second}/

        t.should =~ /Campaign 3/
        t.should =~ /#{values.third}/
      end
    end
  end

  describe '#by_callers(content_type, billable_totals, grand_total, callers)' do
    let(:callers) do
      [
        double('Caller 1', {
          id: 1,
          identity_name: 'Caller 1'
        }),
        double('Caller 2', {
          id: 2,
          identity_name: 'Caller 2'
        }),
        double('Caller 3', {
          id: 3,
          identity_name: 'Caller 3'
        })
      ]
    end
    let(:statuses) do
      ['abandoned', 'voicemail', 'hangup']
    end
    let(:status_values) do
      [45,67,23]
    end
    let(:status_totals) do
      {
        CallAttempt::Status::ABANDONED => status_values.first,
        CallAttempt::Status::VOICEMAIL => status_values.second,
        CallAttempt::Status::HANGUP => status_values.third
      }
    end

    context 'content_type = :html' do
      before do
        @template = @controller.by_callers(:html, billable_totals, status_totals, grand_total, callers)
      end

      it 'renders the html template to a string: views/account_usage_mailer/by_callers' do
        t = @template.to_s

        t.should =~ /<h1.*>Account usage by caller<\/h1>/
        t.should =~ /<th.*>Caller<\/th>/
        t.should =~ /<th.*>Billable minutes<\/th>/

        t.should =~ /<td.*>Caller 1<\/td>/
        t.should =~ /<td.*>#{values.first}<\/td>/

        t.should =~ /<td.*>Caller 2<\/td>/
        t.should =~ /<td.*>#{values.second}<\/td>/

        t.should =~ /<td.*>Caller 3<\/td>/
        t.should =~ /<td.*>#{values.third}<\/td>/

        t.should =~ /<td.*>Abandoned calls<\/td>/
        t.should =~ /<td.*>#{status_values.first}<\/td>/

        t.should =~ /<td.*>Voicemails \/ Hangups<\/td>/
        t.should =~ /<td.*>#{status_values.second + status_values.third}<\/td>/

        t.should =~ /<td.*>Total<\/td>/
        t.should =~ /<td.*>#{grand_total}<\/td>/
      end
    end

    context 'content_type = :text' do
      before do
        @template = @controller.by_callers(:text, billable_totals, status_totals, grand_total, callers)
      end

      it 'renders the text template to a string: views/account_usage_mailer/by_callers' do
        t = @template.to_s

        t.should =~ /Account usage by caller/
        t.should =~ /Caller/
        t.should =~ /Billable minutes/

        t.should =~ /Caller 1/
        t.should =~ /#{values.first}/

        t.should =~ /Caller 2/
        t.should =~ /#{values.second}/

        t.should =~ /Caller 3/
        t.should =~ /#{values.third}/

        t.should =~ /Abandoned calls/
        t.should =~ /#{status_values.first}/

        t.should =~ /Voicemails \/ Hangups/
        t.should =~ /#{status_values.second + status_values.third}/

        t.should =~ /Total/
        t.should =~ /#{grand_total}/
      end
    end
  end
end
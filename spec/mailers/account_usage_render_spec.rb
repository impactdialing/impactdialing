require 'spec_helper'

describe AccountUsageRender, :type => :mailer do
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

        expect(t).to match(/<h1.*>Account usage by campaign<\/h1>/)
        expect(t).to match(/<th.*>Campaign<\/th>/)
        expect(t).to match(/<th.*>Billable minutes<\/th>/)

        expect(t).to match(/<td.*>Campaign 1<\/td>/)
        expect(t).to match(/<td.*>#{values.first}<\/td>/)

        expect(t).to match(/<td.*>Campaign 2<\/td>/)
        expect(t).to match(/<td.*>#{values.second}<\/td>/)

        expect(t).to match(/<td.*>Campaign 3<\/td>/)
        expect(t).to match(/<td.*>#{values.third}<\/td>/)
      end
    end

    context 'content_type = :text' do
      before do
        @template = @controller.by_campaigns(:text, billable_totals, grand_total, campaigns)
      end

      it 'renders the text template to a string: views/account_usage_mailer/by_campaigns' do
        t = @template.to_s

        expect(t).not_to match(/<\w+>/)
        expect(t).to match(/Account usage by campaign/)
        expect(t).to match(/Campaign/)
        expect(t).to match(/Billable minutes/)

        expect(t).to match(/Campaign 1/)
        expect(t).to match(/#{values.first}/)

        expect(t).to match(/Campaign 2/)
        expect(t).to match(/#{values.second}/)

        expect(t).to match(/Campaign 3/)
        expect(t).to match(/#{values.third}/)
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

        expect(t).to match(/<h1.*>Account usage by caller<\/h1>/)
        expect(t).to match(/<th.*>Caller<\/th>/)
        expect(t).to match(/<th.*>Billable minutes<\/th>/)

        expect(t).to match(/<td.*>Caller 1<\/td>/)
        expect(t).to match(/<td.*>#{values.first}<\/td>/)

        expect(t).to match(/<td.*>Caller 2<\/td>/)
        expect(t).to match(/<td.*>#{values.second}<\/td>/)

        expect(t).to match(/<td.*>Caller 3<\/td>/)
        expect(t).to match(/<td.*>#{values.third}<\/td>/)

        expect(t).to match(/<td.*>Abandoned calls<\/td>/)
        expect(t).to match(/<td.*>#{status_values.first}<\/td>/)

        expect(t).to match(/<td.*>Voicemails \/ Hangups<\/td>/)
        expect(t).to match(/<td.*>#{status_values.second + status_values.third}<\/td>/)

        expect(t).to match(/<td.*>Total<\/td>/)
        expect(t).to match(/<td.*>#{grand_total}<\/td>/)
      end
    end

    context 'content_type = :text' do
      before do
        @template = @controller.by_callers(:text, billable_totals, status_totals, grand_total, callers)
      end

      it 'renders the text template to a string: views/account_usage_mailer/by_callers' do
        t = @template.to_s

        expect(t).to match(/Account usage by caller/)
        expect(t).to match(/Caller/)
        expect(t).to match(/Billable minutes/)

        expect(t).to match(/Caller 1/)
        expect(t).to match(/#{values.first}/)

        expect(t).to match(/Caller 2/)
        expect(t).to match(/#{values.second}/)

        expect(t).to match(/Caller 3/)
        expect(t).to match(/#{values.third}/)

        expect(t).to match(/Abandoned calls/)
        expect(t).to match(/#{status_values.first}/)

        expect(t).to match(/Voicemails \/ Hangups/)
        expect(t).to match(/#{status_values.second + status_values.third}/)

        expect(t).to match(/Total/)
        expect(t).to match(/#{grand_total}/)
      end
    end
  end
end
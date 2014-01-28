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

  describe '#by_campaigns(content_type, billable_totals, grand_total, campaigns)' do
    before do
      @controller = AccountUsageRender.new
    end
    context 'content_type = ":html"' do
      before do
        @template = @controller.by_campaigns(:html, billable_totals, grand_total, campaigns)
      end
      it 'renders the html template to a string: views/account_usage_mailer/by_campaigns' do
        t = @template.to_s

        t.should =~ /<h1>Account usage by campaign<\/h1>/
        t.should =~ /<th>Campaign<\/th>/
        t.should =~ /<th>Billable minutes<\/th>/

        t.should =~ /<td>Campaign 1<\/td>/
        t.should =~ /<td>#{values.first}<\/td>/

        t.should =~ /<td>Campaign 2<\/td>/
        t.should =~ /<td>#{values.second}<\/td>/

        t.should =~ /<td>Campaign 3<\/td>/
        t.should =~ /<td>#{values.third}<\/td>/
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
end
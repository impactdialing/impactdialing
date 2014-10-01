require 'spec_helper'
require 'impact_platform/heroku'


# app=impactdialing-staging
# form=upload_download

## formation_info.json
# curl -n -X GET -is https://api.heroku.com/apps/$app/formation/$form \
# -H "Accept: application/vnd.heroku+json; version=3" > formation_info.json

## formation_update.json
# curl -n -X PATCH -is https://api.heroku.com/apps/$app/formation/$form \
# -H "Accept: application/vnd.heroku+json; version=3" \
# -H "Content-Type: application/json" \
# -d '{"quantity":1,"size":"1X"}' > formation_update.json


describe ImpactPlatform::Heroku::Scale do
  let(:response_root){ File.join Rails.root, 'spec', 'lib', 'impact_platform', 'heroku_responses' }
  let(:metrics) do
    double('ImpactPlatform::Metrics')
  end
  let(:app){ 'impactdialing-staging' }
  let(:process){ 'some_dyno_process' }
  let(:desired_quantity){ 3 }
  let(:formation_url){ "https://api.heroku.com/apps/#{app}/formation/#{process}" }
  let(:formation_update_response){ File.new(File.join response_root, 'formation_update.json') }
  let(:formation_info_response){ File.new(File.join response_root, 'formation_info.json') }

  before do
    WebMock.disable_net_connect!
    ENV['HEROKU_AUTOSCALE_OAUTH_TOKEN'] = 'foobar'
    allow(ImpactPlatform::Metrics).to receive(:new){ metrics }
    stub_request(:get, formation_url).to_return(formation_info_response)
    stub_request(:patch, formation_url).to_return(formation_update_response)
  end

  describe '#auto!' do
    context '#env not in #envs_available' do
      subject{ ImpactPlatform::Heroku::Scale.new(process, desired_quantity, 'carnival') }

      it 'does nothing' do
        subject.auto!
        expect(WebMock).to_not have_requested(:patch, formation_url)
        expect(WebMock).to_not have_requested(:get, formation_url)
      end
    end

    context '#env is in #envs_available' do

      context '#current_quantity == #desired_quantity' do
        let(:desired_quantity){ 1 } # 1 is quantity returned by response fixture

        it 'does nothing' do
          scale = ImpactPlatform::Heroku::Scale.new(process, desired_quantity, 'test')
          expect(scale.desired_quantity).to eq desired_quantity
          scale.auto!

          expect(WebMock).to_not have_requested(:patch, formation_url)
        end
      end

      context '#current_quantity != #desired_quantity' do
        let(:desired_quantity){ 3 }
        it 'requests that dynos for process name be scaled to #desired_quantity' do
          ENV['ENABLE_WORKER_AUTOSCALING'] = '1'
          scale = ImpactPlatform::Heroku::Scale.new(process, desired_quantity, 'test')
          scale.auto!
          expect(WebMock).to have_requested(:patch, formation_url)
        end
      end
    end
  end
end

describe ImpactPlatform::Heroku::Scale::BackgroundScaleRules do
  describe '#active_rule' do
    let(:process){ 'queue_name' }
    let(:rules){ ImpactPlatform::Heroku::Scale::BackgroundScaleRules.new(process) }

    before do
      allow(Resque).to receive(:size).with(process){ 0 }
    end

    it 'returns first if queue size is zero' do
      expect(rules.active_rule).to eq rules.default_rules.first
    end
  end
end

require 'rails_helper'

describe Callers::StationController do
  include FakeCallData
  include ListHelpers

  before do
    admin       = create(:user)
    other_admin = create(:user)
    @account    = admin.account
    @campaign   = create_campaign_with_script(:bare_power, @account).last
    @caller     = create(:caller, {campaign: @campaign, account: @account})
  end

  shared_context 'browser requests' do
    let(:voter_list){ create(:voter_list, campaign: @campaign) }
    let(:phone){ Forgery(:address).clean_phone }
    let(:call_sid){ 'CA-123' }
    let(:browser_params) do
      {
        'sid' => call_sid,
        'lead' => build_lead_hash(voter_list, phone).stringify_keys,
        'question' => {
          '42' => "123",
          '43' => "128",
          '44' => "136"
        },
        'notes' => {
          'Suggestions' => 'Would like bouncier material.'
        }
      }
    end

    before do
      login_as(@caller)
    end
  end

  describe '#drop_message' do
    include_context 'browser requests'
    let(:dialed_call){ double('CallFlow::Call::Dialed', {drop_message: nil}) }

    before do
      allow(CallFlow::Call::Dialed).to receive(:new){ dialed_call }
    end

    it 'tells CallFlow::Call::Dialed instance :drop_message' do
      expect(dialed_call).to receive(:drop_message)
      post :drop_message, browser_params
    end

    it 'renders nothing' do
      post :drop_message, browser_params
      expect(response.body).to be_blank
    end
  end

  describe '#disposition' do
    include_context 'browser requests'
    let(:dialed_call){ double('CallFlow::Call::Dialed', caller_session_sid: 'ca-321', dispositioned: nil) }

    before do
      allow(CallFlow::Call::Dialed).to receive(:new){ dialed_call }
    end

    shared_examples_for 'all dispositions' do
      it 'tells CallFlow::Call::Dialed instance :dispositioned' do
        expected_params = browser_params.merge({
          'action' => 'disposition',
          'controller' => 'callers/station'
        })
        expect(dialed_call).to receive(:dispositioned).with(expected_params)

        post :disposition, browser_params
      end

      it 'renders nothing' do
        post :disposition, browser_params
        expect(response.body).to be_blank
      end
    end

    it_behaves_like 'all dispositions'

    context ':sid param is not present' do
      let(:caller_session) do
        create(:webui_caller_session, {
          sid: dialed_call.caller_session_sid,
          campaign: @campaign
        })
      end

      before do
        browser_params.delete 'sid'
        browser_params.merge!(caller_session_id: caller_session.id.to_s)
        allow(caller_session).to receive(:dialed_call){ dialed_call }
        expect(CallerSession).to receive(:find){ caller_session }
      end

      it 'loads dialed_call via CallerSession' do
        expect(caller_session).to receive(:dialed_call){ dialed_call }
        post :disposition, browser_params
      end

      it_behaves_like 'all dispositions'
    end
  end

  describe '#hangup_lead' do
    include_context 'browser requests'

    it 'queues EndRunningCallJob' do
      post :hangup_lead, sid: call_sid
      expect([:sidekiq, :call_flow]).to have_queued(EndRunningCallJob).with(call_sid)
    end

    it 'renders nothing' do
      post :hangup_lead, sid: call_sid
      expect(response.body).to be_blank
    end
  end

  describe '#login' do
    context 'Caller#campaign_id is blank' do
      before do
        @caller.update_attributes!(campaign_id: nil)
        post :login, username: @caller.username, password: @caller.password
      end

      it 're-renders login form' do
        expect(response).to render_template 'callers/station/login'
      end
    end
    context 'Caller#campaign is archived' do
      before do
        campaign = @caller.campaign
        campaign.active = false
        campaign.save!
        post :login, username: @caller.username, password: @caller.password
      end

      it 're-renders login form' do
        expect(response).to render_template 'callers/station/login'
      end
    end
  end

  describe '#logout' do
    before do
      post :login, username: @caller.username, password: @caller.password
      expect(response.headers['Location']).to match /#{callveyor_path}/
    end

    it 'clears session[:caller]' do
      post :logout
      expect(session[:caller]).to be_nil
    end

    it 'redirects to /login' do
      post :logout
      expect(response).to redirect_to callveyor_login_path
    end
  end
  
  describe '#show?campaign_id' do
    before do
      admin                = create(:user)
      other_admin          = create(:user)
      @account             = admin.account
      @other_account       = other_admin.account
      @campaign            = create_campaign_with_script(:bare_power, @account).last
      @assignable_campaign = create_campaign_with_script(:bare_power, @account).last
      @other_campaign      = create_campaign_with_script(:bare_power, @other_account).last
      @caller              = create(:caller, {campaign: @campaign, account: @account})
    end

    context 'Caller#campaign_id is nil (possible if caller session still active after campaign archive)' do
      before do
        login_as(@caller)
        @caller.update_attributes!(campaign_id: nil)
      end

      shared_examples 'whenever Caller#campaign_id is nil' do
        it 'clears session[:caller]' do
          self.send(verb, action)
          expect(session[:caller]).to be_nil
        end
        it 'redirects to login page' do
          self.send(verb, action)
          expect(response).to redirect_to callveyor_login_path
        end
      end

      context '#show' do
        let(:verb){ :get }
        let(:action){ :show }
        it_behaves_like 'whenever Caller#campaign_id is nil'
      end

      context '#script' do
        let(:verb){ :get }
        let(:action){ :script }
        it_behaves_like 'whenever Caller#campaign_id is nil'
      end

      context '#create' do
        let(:verb){ :post }
        let(:action){ :create }
        it_behaves_like 'whenever Caller#campaign_id is nil'
      end
    end
    
    context 'campaign_id is present in params' do
      before do
        login_as(@caller)
      end
      context 'campaign_id identifies Campaign not associated with @caller.account_id' do
        let(:params) do
          {campaign_id: @other_campaign.id}
        end
        it 'does not assign @caller to other campaign' do
          get :show, params
          @caller.reload
          expect(@caller.campaign_id).to eq @campaign.id
        end
        it 'renders callers/station/show.html.erb' do
          get :show, params
          expect(response).to render_template 'callers/station/show'
        end
      end

      context 'campaign_id identifies Campaign that is associated with @caller.account_id' do
        let(:params) do
          {campaign_id: @assignable_campaign.id}
        end
        it 'assigns @caller to Campaign identified by campaign_id' do
          get :show, params
          @caller.reload
          expect(@caller.campaign_id).to eq @assignable_campaign.id
        end

        it 'renders callers/station/show.html.erb' do
          get :show, params
          expect(response).to render_template 'callers/station/show'
        end
      end
    end
  end
end

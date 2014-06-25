require 'spec_helper'

describe Providers::Phone::Call::Params::CallerSession do
  include Rails.application.routes.url_helpers

  let(:caller) do
    mock_model('Caller')
  end
  let(:campaign) do
    mock_model('Campaign')
  end
  let(:caller_session) do
    mock_model('CallerSession', {
      sid: '123123',
      caller: caller,
      campaign: campaign
    })
  end
  let(:param_class) do
    Providers::Phone::Call::Params::CallerSession
  end
  let(:url_opts) do
    Providers::Phone::Call::Params.default_url_options
  end

  describe 'returning urls based on caller_session record and type requested' do
    it '#call_sid always returns CallerSession#sid' do
      param_class.new(caller_session).call_sid.should eq caller_session.sid
    end

    context 'type == :default and caller_session.caller.is_phones_only? is true' do
      before do
        caller.stub(:is_phones_only?){ true }
      end

      it 'returns ready_to_call_caller_url' do
        params = param_class.new(caller_session, :default)
        params.url.should eq ready_to_call_caller_url(caller, url_opts.merge(session_id: caller_session.id))
      end
    end

    context 'type == :default and caller_session.caller.is_phones_only? is false' do
      before do
        caller.stub(:is_phones_only?){ false }
      end
      it 'returns continue_conf_caller_url' do
        params = param_class.new(caller_session, :default)
        params.url.should eq continue_conf_caller_url(caller, url_opts.merge(session_id: caller_session.id))
      end
    end

    context '#return_url? is true' do
      before do
        caller_session.stub(:available_for_call?){ true }
        campaign.stub(:type){ 'Power' }
      end
      context 'type == :out_of_numbers' do
        it 'returns run_out_of_numbers_caller_url' do
          params = param_class.new(caller_session, :out_of_numbers)
          params.url.should eq run_out_of_numbers_caller_url(caller, url_opts.merge(session_id: caller_session.id))
        end
      end

      context 'type == :time_period_exceeded' do
        it 'returns time_period_exceeded_caller_url' do
          params = param_class.new(caller_session, :time_period_exceeded)
          params.url.should eq time_period_exceeded_caller_url(caller, url_opts.merge(session_id: caller_session.id))
        end
      end

      context 'type == :account_has_no_funds' do
        it 'returns account_out_of_funds_caller_url' do
          params = param_class.new(caller_session, :account_has_no_funds)
          params.url.should eq account_out_of_funds_caller_url(caller, url_opts.merge(session_id: caller_session.id))
        end
      end

      context 'type == :play_message_error' do
        it 'returns play_message_error_caller_url(caller)' do
          params = param_class.new(caller_session, :play_message_error)
          params.url.should eq play_message_error_caller_url(caller, url_opts.merge(session_id: caller_session.id))
        end
      end
    end

    context '#return_url? is false' do
      before do
        caller_session.stub(:available_for_call?){ false }
        campaign.stub(:type){ 'Predictive' }
      end
      context 'type == :out_of_numbers' do
        it 'returns run_out_of_numbers_caller_url' do
          params = param_class.new(caller_session, :out_of_numbers)
          params.url.should eq nil
        end
      end

      context 'type == :time_period_exceeded' do
        it 'returns time_period_exceeded_caller_url' do
          params = param_class.new(caller_session, :time_period_exceeded)
          params.url.should eq nil
        end
      end

      context 'type == :account_has_no_funds' do
        it 'returns account_out_of_funds_caller_url' do
          params = param_class.new(caller_session, :account_has_no_funds)
          params.url.should eq nil
        end
      end
    end
  end
end

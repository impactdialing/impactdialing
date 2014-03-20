require 'spec_helper'
require 'cancan/matchers'

describe Ability do
  let(:account){ create(:account) }
  let(:subscription){ account.billing_subscription }
  let(:quota){ account.quota }

  def subscribe(plan, status='active')
    subscription.plan = plan
    unless plan == 'trial'
      # mimic reality, where trial subs have no provider_status
      subscription.provider_status = status
    end
    subscription.save!
  end

  def toggle_calling(flag)
    quota.disable_calling = (flag == :off)
    quota.save!
  end

  def take_all_seats
    CallerSession.stub_chain(:on_call_in_campaigns, :count){ quota.callers_allowed }
  end

  def set_minutes_allowed(n)
    quota.minutes_allowed = n
    quota.save!
  end

  def use_all_minutes
    quota.minutes_used = quota.minutes_allowed
    quota.save!
  end

  def set_seats(n)
    quota.callers_allowed = n
    quota.save!
  end

  context 'plan permissions' do
    context 'account.billing_provider_customer_id is present' do
      before do
        account.billing_provider_customer_id = 'cus_abc123'
        account.save!
      end
      let(:ability){ Ability.new(account) }
      it 'can make payment' do
        ability.should be_able_to :make_payment, subscription
      end
      it 'can change plans' do
        ability.should be_able_to :change_plans, subscription
      end
      context 'plan is per minute' do
        before do
          subscribe 'per_minute'
        end
        let(:ability){ Ability.new(account) }
        it 'can add minutes' do
          ability.should be_able_to :add_minutes, subscription
        end
      end
      context 'plan is not per minute' do
        it 'cannot add minutes' do
          ['trial', 'basic', 'pro', 'business'].each do |id|
            subscribe id
            ability = Ability.new(account)
            ability.should_not be_able_to :add_minutes, subscription
          end
        end
      end
    end
    context 'account.billing_provider_customer_id is not present' do
      let(:ability){ Ability.new(account) }

      it 'cannot make payment' do
        ability.should_not be_able_to :make_payment, subscription
      end
      it 'cannot change plans' do
        ability.should_not be_able_to :change_plans, subscription
      end
      it 'cannot add minutes' do
        ability.should_not be_able_to :add_minutes, subscription
      end
    end
    context 'plan is not trial and plan is not per minute and plan is not enterprise' do
      it 'can cancel subscription' do
        ['basic', 'pro', 'business'].each do |id|
          subscribe id
          ability = Ability.new(account)
          ability.should be_able_to :cancel_subscription, subscription
        end
      end
    end
    context 'plan is trial, per minute or enterprise' do
      it 'cannot cancel subscription' do
        ['trial', 'per_minute', 'enterprise'].each do |id|
          subscribe id
          ability = Ability.new(account)
          ability.should_not be_able_to :cancel_subscription, subscription
        end
      end
    end
  end

  context 'quota permissions' do
    shared_examples_for 'dialer access denied' do
      let(:ability){ Ability.new(account) }
      it 'cannot start calling' do
        ability.should_not be_able_to :start_calling, Caller
      end
      it 'cannot dial' do
        ability.should_not be_able_to :dial, Caller
      end
    end
    shared_examples_for 'dialer access granted' do
      let(:ability){ Ability.new(account) }
      it 'can start calling' do
        ability.should be_able_to :start_calling, Caller
      end
      it 'can dial' do
        ability.should be_able_to :dial, Caller
      end
    end
    context 'enterprise' do
      before do
        subscribe 'enterprise'
      end
      it_behaves_like 'dialer access granted'
      context 'calling is disabled' do
        before do
          toggle_calling :off
        end
        it_behaves_like 'dialer access denied'
      end
    end
    context 'per minute' do
      before do
        subscribe 'per_minute'
      end
      context 'minutes are available, subscription is active and calling is enabled' do
        before do
          set_minutes_allowed 100
          toggle_calling :on
        end
        it_behaves_like 'dialer access granted'
      end
      context 'no minutes available or subscription is not active or calling is disabled' do
        context 'no minutes' do
          before do
            use_all_minutes
          end
          it_behaves_like 'dialer access denied'
        end
        context 'calling is disabled' do
          before do
            toggle_calling :off
          end
          it_behaves_like 'dialer access denied'
        end
      end
    end
    ['business', 'pro', 'basic', 'trial'].each do |plan_id|
      context "#{plan_id}" do
        before do
          subscribe plan_id
        end
        context 'caller seats and minutes are available and subscription is active and calling is not disabled' do
          it_behaves_like 'dialer access granted'
        end
        context 'no seats available' do
          before do
            take_all_seats
          end
          it_behaves_like 'dialer access denied'
        end
        context 'no minutes available' do
          before do
            use_all_minutes
          end
          it_behaves_like 'dialer access denied'
        end
      end
    end
  end

  context 'feature permissions' do
    ['enterprise', 'per_minute', 'business', 'trial'].each do |plan_id|
      context "#{plan_id}" do
        before do
          subscribe plan_id
        end
        let(:ability){ Ability.new(account) }

        it 'can add transfers' do
          ability.should be_able_to :add_transfer, Script
        end
        it 'can manager caller groups' do
          ability.should be_able_to :manage, CallerGroup
        end
        it 'can view campaign reports' do
          ability.should be_able_to :view_campaign_reports, Account
        end
        it 'can view caller reports' do
          ability.should be_able_to :view_caller_reports, Account
        end
        it 'can view dashboard' do
          ability.should be_able_to :view_dashboard, Account
        end
        it 'can record calls' do
          ability.should be_able_to :record_calls, Account
        end
        it 'can manage Preview, Power and Predictive campaigns' do
          ability.should be_able_to :manage, Preview
          ability.should be_able_to :manage, Power
          ability.should be_able_to :manage, Predictive
        end
      end
    end
    context 'pro' do
      before do
        subscribe 'pro'
      end
      let(:ability){ Ability.new(account) }
      it 'can add transfers' do
        ability.should be_able_to :add_transfer, Script
      end
      it 'can manager caller groups' do
        ability.should be_able_to :manage, CallerGroup
      end
      it 'can view campaign reports' do
        ability.should be_able_to :view_campaign_reports, Account
      end
      it 'can view caller reports' do
        ability.should be_able_to :view_caller_reports, Account
      end
      it 'can view dashboard' do
        ability.should be_able_to :view_dashboard, Account
      end
      it 'cannot record calls' do
        ability.should_not be_able_to :record_calls, Account
      end
      it 'can manage Preview, Power and Predictive campaigns' do
        ability.should be_able_to :manage, Preview
        ability.should be_able_to :manage, Power
        ability.should be_able_to :manage, Predictive
      end
    end
    context 'basic' do
      before do
        subscribe 'basic'
      end
      let(:ability){ Ability.new(account) }
      it 'cannot add transfers' do
        ability.should_not be_able_to :add_transfer, Script
      end
      it 'cannot manage caller groups' do
        ability.should_not be_able_to :manage, CallerGroup
      end
      it 'cannot view campaign reports' do
        ability.should_not be_able_to :view_campaign_reports, Account
      end
      it 'cannot view caller reports' do
        ability.should_not be_able_to :view_caller_reports, Account
      end
      it 'cannot view dashboard' do
        ability.should_not be_able_to :view_dashboard, Account
      end
      it 'cannot record calls' do
        ability.should_not be_able_to :record_calls, Account
      end
      it 'can manage Preview and Power campaigns' do
        ability.should be_able_to :manage, Preview
        ability.should be_able_to :manage, Power
      end
      it 'cannot manage Predictive campaigns' do
        ability.should_not be_able_to :manage, Predictive
      end
    end
  end
end
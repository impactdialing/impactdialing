## Example script to pull recordings for given list of phone numbers
#
# account = Account.find xxx
# phone_numbers = ['xxx','yyy']
# voters = account.voters.where(phone: phone_numbers)
# out = ''
# voters.each do |v|
#   out << "#{v.phone}\n"
#   call_attempts = v.call_attempts.where('recording_url is not null').order('voter_id DESC')
#   call_attempts.each do |ca|
#     out << "- #{ca.tStartTime.strftime('%m/%d/%Y at %I:%M%P')} #{ca.recording_url}\n"
#   end
# end
# print out

namespace :billing_v2 do
  desc "Migrate accounts to billing v2"
  task :migrate_accounts, [:dry_run] => :environment do |t,args|
    if args[:dry_run].present?
      dry_run = args[:dry_run]
    else
      dry_run = 'on'
    end

    print "\nRunning with dry run: #{dry_run}\n"

    # helpers to build attr hashes
    create_card_attrs = -> (account, customer, subscription) {
      if Rails.env.heroku_staging? && subscription.cc_last4.present? && subscription.exp_month.present? && subscription.exp_year.present?
        return {
          last4: subscription.cc_last4,
          exp_month: subscription.exp_month,
          exp_year: subscription.exp_year
        }
      else
        return {} if customer.nil?
        customer_card = customer.cards.data.first
        return {} if customer_card.nil?
      end
      {
        last4: customer_card.last4,
        exp_month: customer_card.exp_month,
        exp_year: customer_card.exp_year,
        provider_id: customer_card.id
      }
    }
    create_quota_attrs = -> (account, subscription) {
      {
        minutes_used: subscription.minutes_utlized,
        minutes_allowed: subscription.total_allowed_minutes,
        callers_allowed: subscription.number_of_callers
      }
    }
    create_subscription_attrs = -> (account, subscription, plan, customer) {
      a = {
        plan: plan
      }
      if Rails.env.heroku_staging? && subscription.subscription_start_date.present? && subscription.subscription_end_date.present?
        a.merge!({
          provider_start_period: subscription.subscription_start_date,
          provider_end_period: subscription.subscription_end_date
        })
        return a
      end

      if customer.present?
        customer_subscription = customer.subscriptions.data.first
      end
      if customer.present? && customer_subscription.present?
        a.merge!({
          provider_id: customer_subscription.id,
          provider_status: customer_subscription.status,
          provider_start_period: customer_subscription.current_period_start,
          provider_end_period: customer_subscription.current_period_end
        })
      end
      a
    }
    # /helpers to build attr hashes

    subscribers = {
      trial: [],
      basic: [],
      pro: [],
      business: [],
      per_minute: [],
      enterprise: [],
      unknown: [],
      previously_processed: [],
      no_current_subscription: []
    }

    Account.all.each do |account|
      subscription = account.current_subscription
      if subscription.present?
        plan = subscription.type.to_s.underscore
      else
        subscribers[:no_current_subscription] << {
          account_id: account.id,
          quota: {},
          subscription: {},
          card: {},
          billing_provider_customer_id: ''
        }
        next
      end

      if (not Rails.env.heroku_staging?) && subscription.stripe_customer_id.present?
        payment_gateway = Billing::PaymentGateway.new(subscription.stripe_customer_id)
        customer        = payment_gateway.customer
      end

      if account.billing_credit_card.present? ||
        (account.billing_subscription.present? && account.quota.present?)
        subscribers[:previously_processed] << {
          account_id: account.id,
          quota: account.quota.attributes,
          subscription: account.billing_subscription.attributes,
          card: (account.billing_credit_card.try(:attributes) || {}),
          billing_provider_customer_id: account.billing_provider_customer_id
        }
        next
      end

      details      = {
        account_id: account.id,
        quota: create_quota_attrs.call(account, subscription),
        subscription: create_subscription_attrs.call(account, subscription, plan, customer),
        card: create_card_attrs.call(account, customer, subscription),
        billing_provider_customer_id: subscription.stripe_customer_id
      }

      unless subscribers[plan.intern].present? && subscribers[plan.intern].kind_of?(Array)
        subscribers[:unknown] << details
        next
      end

      if dry_run == 'off'
        account.transaction do
          unless details[:card].empty?
            account.create_billing_credit_card(details[:card])
          end
          account.create_quota(details[:quota])

          billing_subscription = account.create_billing_subscription(details[:subscription])
          if plan == 'per_minute' && subscription.autorecharge_trigger.present? && subscription.autorecharge_amount.present?
            # Disable auto-recharges to make sure we don't accidentally create
            # a charge in case an account is below their trigger.
            billing_subscription.update_autorecharge_settings!({
              enabled: 0,
              trigger: subscription.autorecharge_trigger.to_i,
              amount: subscription.autorecharge_amount.to_i
            })
          end
          account.save!
        end
      end

      subscribers[plan.intern] << details
    end

    print "\n\nMigrated a total of #{Account.count} accounts.\n"
    subscribers.each do |k,v|
      print "#{v.size} subscribed to #{k.to_s.humanize}\n"
      print "\tAccount IDS: #{v.map{|d| d[:account_id]}.join('", "')}\n"
    end
    print "\n**NOTE** accounts on unknown plans were not touched.\n"
    print "\nAnd now for the gory deets (TSV):\n\n"
    print "Subscription status\tAccount ID\tStripe Customer ID\tSubscription details\tQuota details\tCard details\n"
    subscribers.each do |k,v|
      v.each do |deets|
        print "#{k.to_s.humanize}\t"
        print "#{deets[:account_id]}\t"
        print "#{deets[:billing_provider_customer_id]}\t"
        print "#{deets[:subscription]}\t"
        print "#{deets[:quota]}\t"
        print "#{deets[:card]}\n"
      end
    end
  end
end

desc "Renew a subscription for one or more account ids"
task :renew_subscription, [:account_ids] => :environment do |t, args|
  account_ids = args[:account_ids]
  account_ids = account_ids.split(':')
  if account_ids.empty?
    p "Please provide one or more account IDs."
    exit
  end

  account_ids.each do |id|
    account = Account.find id
    subscription = account.current_subscription
    subscription.subscription_start_date = subscription.subscription_start_date + 1.month
    subscription.subscription_end_date = subscription.subscription_end_date + 1.month
    subscription.save!

    p "Account ##{id} renewed now good from #{subscription.subscription_start_date} - #{subscription.subscription_end_date}"
  end
end

desc "sync Voters#enabled w/ VoterList#enabled"
task :sync_all_voter_lists_to_voter => :environment do |t, args|
  limit = 100
  offset = 0

  lists = VoterList.limit(limit).offset(offset)

  until lists.empty?
    lists.each do |list|
      list.voters.update_all(enabled: list.enabled)
    end

    offset += limit
    lists = VoterList.limit(limit).offset(offset)
  end
end

desc "Read phone numbers from csv file and output as array."
task :extract_numbers, [:filepath, :account_id, :campaign_id, :target_column_index] => :environment do |t, args|
  require 'csv'

  account_id = args[:account_id]
  campaign_id = args[:campaign_id]
  target_column_index = args[:target_column_index].to_i
  filepath = args[:filepath]
  numbers = []

  CSV.foreach(File.join(Rails.root, filepath)) do |row|
    numbers << row[target_column_index]
  end

  print "\n"
  numbers.shift # lose the header
  print "numbers = #{numbers.compact}\n"
  print "account = Account.find(#{account_id})\n"
  if campaign_id.present?
    print "campaign = account.campaigns.find(#{campaign_id})\n"
    print "columns = [:account_id, :campaign_id, :number]\n"
    print "values = numbers.map{|number| [account.id, campaign.id, number]}\n"
  else
    print "columns = [:account_id, :number]\n"
    print "values = numbers.map{|number| [account.id, number]}\n"
  end
  print "BlockedNumber.import columns, values\n"
  print "\n"
end

desc 'Long running task to test DNS resolution to 3rd party APIs success over time'
task :dns do
  require 'resolv'
  require 'benchmark'

  names = {
    'api.twilio.com' => 'Twilio',
    'api.pusherapp.com' => 'Pusher',
    'impact-prod-db.cjo94dhm4pos.us-east-1.rds.amazonaws.com' => 'RDS'
  }

  domains = {
    'api.twilio.com' => 330,
    'api.pusherapp.com' => 90,
    'impact-prod-db.cjo94dhm4pos.us-east-1.rds.amazonaws.com' => 30
  }

  results = {}
  domains.each do |domain, delay|
    results[domain] = {
      answer: '',
      time: ''
    }
  end

  time_asleep = 0
  960.times do |n|
    domains.each do |domain, delay|
      unless time_asleep % delay == 0
        next
      end
      print "Resolving #{names[domain]}: "
      resolvr = Resolv::DNS.new
      begin
        results[domain][:time] = Benchmark.measure do
          results[domain][:answer] = resolvr.getaddress(domain).to_s
        end
      rescue Resolv::ResolvError => e
        results[domain][:answer] = "#{e.class}: #{e.message}"
      ensure
        # log results
        print "#{results[domain][:answer]}\t"
        print "#{results[domain][:time]}\n"
      end
    end
    resolvr = nil
    sleep(30)
    time_asleep += 30
  end
end

desc "Generate / append to CHANGELOG.md entries within the start_date and end_date"
task :changelog, [:after, :before] do |t, args|
  desired_entries = [
    'changelog',
    'closes',
    'fixes',
    'completes',
    'delivers',
    '#'
  ]
  format = 'format:"%cr%n-----------%n%s%+b%n========================================================================"'
  after = args[:after]
  before = args[:before]
  cmd = 'git log'
  cmd << " --pretty=#{format}"
  desired_entries.each do |de|
    cmd << " --grep='#{de}'"
  end
  cmd << " --after='#{after}'" unless after.blank?
  cmd << " --before='#{before}'" unless before.blank?
  print cmd + "\n"
end

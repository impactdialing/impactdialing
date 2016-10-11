class Predictive < Campaign
  include SidekiqEvents

  def number_ringing
    counts = Wolverine.dial_queue.number_ringing(keys: [Twillio::InflightStats.key(self)])
    debug_number_ringing(counts)
  end

  def number_failed
    debug_number('failed', 'presented') do
      inflight_stats.incby('presented', -1)
    end
  end

  def number_presented(n)
    debug_number('presented', 'presented') do
      inflight_stats.incby('presented', n)
    end
  end

  def any_numbers_to_dial?
    numbers_to_dial_count > 0
  end

  def available_callers_count
    caller_sessions.available.count
  end

  def answered_count
    call_attempts.with_status(CallAttempt::Status::SUCCESS).count
  end

  def abandoned_count
    call_attempts.with_status(CallAttempt::Status::ABANDONED).count
  end

  def abandon_rate
    FccCompliance.abandon_rate(answered_count, abandoned_count)
  end

  def abandon_rate_acceptable?
    abandon_rate <= acceptable_abandon_rate
  end

  def best_dials_simulated
    return 1 if simulated_values.nil? || simulated_values.best_dials.nil?
    n = simulated_values.best_dials
    return n > TwilioLimit.get ? TwilioLimit.get : n
  end

  def dial_factor
    dials_made = call_attempts.between(10.minutes.ago, Time.now).count

    return 1 if dials_made.zero?
    if !abandon_rate_acceptable?
      half_speed = 0.75 * best_dials_simulated
      if half_speed < 1
        return 1
      else
        return half_speed
      end
    end
    return best_dials_simulated
  end

  def numbers_to_dial_count
    deductibles = [ringing_count, 0].max + [presented_count, 0].max
    n = (
      (dial_factor * available_callers_count) - deductibles
    ).to_i

    if n > (TwilioLimit.get * available_callers_count)
      n = available_callers_count - deductibles
    end

    return n
  end

  def next_in_dial_queue(n)
    houses = dial_queue.next(n)
    return [] if houses.nil?

    houses.map do |house|
      if house.blank? or house[:leads].blank?
        if house.blank?
          p "[Predictive] CampaignID[#{self.id}] House was nil."
          next
        end
        if house[:leads].blank?
          p "[Predictive] CampaignID[#{self.id}] Leads were empty for House[#{house}]."
          next
        end
      else
        house[:leads].compact.first[:phone]
      end
    end.compact
  end

  def numbers_to_dial
    n             = numbers_to_dial_count
    phone_numbers = []
    return phone_numbers if n < 1

    timing('dialer.voter_load') do
      phone_numbers = next_in_dial_queue(n)
      number_presented(phone_numbers.size)
    end

    return phone_numbers
  end

  def abort_calling_with(caller_session, reason)
    Providers::Phone::Call.redirect_for(caller_session, reason)
  end

  def abort_available_callers_with(twilio_redirect)
    caller_sessions.available.each do |cs|
      abort_calling_with(cs, twilio_redirect)
    end
    caller_sessions.available.update_all(available_for_call: false)
  end

  def best_conversation_simulated
    simulated_values.nil? ? 1000 : (simulated_values.best_conversation.nil? || simulated_values.best_conversation == 0) ? 1000 : simulated_values.best_conversation
  end

  def longest_conversation_simulated
    simulated_values.nil? ? 1000 : simulated_values.longest_conversation.nil? ? 0 : simulated_values.longest_conversation
  end

  def best_wrapup_simulated
    simulated_values.nil? ? 1000 : (simulated_values.best_wrapup_time.nil? || simulated_values.best_wrapup_time == 0) ? 1000 : simulated_values.best_wrapup_time
  end

  def caller_conference_started_event
    {event: 'caller_connected_dialer',data: {}}
  end

  def voter_connected_event(call_sid, phone)
    data  = CallFlow::Web::Data.new(script)
    house = dial_queue.presented_households.find(phone)

    return {
      event: 'voter_connected_dialer',
      data: {
        household: data.build(house),
        call_sid:   call_sid
      }
    }
  end
end

# ## Schema Information
#
# Table name: `campaigns`
#
# ### Columns
#
# Name                                      | Type               | Attributes
# ----------------------------------------- | ------------------ | ---------------------------
# **`id`**                                  | `integer`          | `not null, primary key`
# **`name`**                                | `string(255)`      |
# **`account_id`**                          | `integer`          |
# **`script_id`**                           | `integer`          |
# **`active`**                              | `boolean`          | `default(TRUE)`
# **`created_at`**                          | `datetime`         |
# **`updated_at`**                          | `datetime`         |
# **`caller_id`**                           | `string(255)`      |
# **`type`**                                | `string(255)`      |
# **`recording_id`**                        | `integer`          |
# **`use_recordings`**                      | `boolean`          | `default(FALSE)`
# **`calls_in_progress`**                   | `boolean`          | `default(FALSE)`
# **`recycle_rate`**                        | `integer`          | `default(1)`
# **`answering_machine_detect`**            | `boolean`          |
# **`start_time`**                          | `time`             |
# **`end_time`**                            | `time`             |
# **`time_zone`**                           | `string(255)`      |
# **`acceptable_abandon_rate`**             | `float`            |
# **`call_back_after_voicemail_delivery`**  | `boolean`          | `default(FALSE)`
# **`caller_can_drop_message_manually`**    | `boolean`          | `default(FALSE)`
#

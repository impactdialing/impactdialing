class Payment < ActiveRecord::Base
  belongs_to :account

  def debit_call_charge(call_charge, account)
    remaining_amount = amount_remaining - call_charge
    update_attributes(amount_remaining: remaining_amount)
  end

  def self.charge_recurly_account(account, amount, notes)
      recurly_account = Recurly::Account.find(account.recurly_account_code)
      transaction = recurly_account.transactions.create(
        :description     => notes,
        :amount_in_cents => (amount.to_f*100).to_i,
        :currency        => 'USD',
        :account         => { :account_code => account.recurly_account_code }
      )
      if transaction.status=="success"
        account.update_attributes(credit_card_declined: false)
        p = Payment.new(:amount_paid=>amount, :amount_remaining=>amount, :account_id=>account.id, :notes=>notes, :recurly_transaction_uuid=>transaction.uuid)
        p.save
        return p
      else
        account.update_attributes(autorecharge_enabled: false, credit_card_declined: true)
        UserMailer.new.deliver_update_billing_info(account)
        return nil
      end
  end

end

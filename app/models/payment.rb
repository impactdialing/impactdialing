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
        p = Payment.new(:amount_paid=>amount, :amount_remaining=>amount, :account_id=>account.id, :notes=>notes, :recurly_transaction_uuid=>transaction.uuid)
        p.save
        return p
      else
        return nil
      end      
  end

end

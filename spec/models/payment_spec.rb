require 'spec_helper'

describe Payment do
  it "should debit balance for call" do
    account = create(:account)
    payment = create(:payment, account_id: account.id, amount_remaining: 10.00)
    payment.debit_call_charge(0.27, account)
    payment.amount_remaining.should eq(9.73)
  end
end

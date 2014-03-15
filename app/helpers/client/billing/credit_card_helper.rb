module Client::Billing::CreditCardHelper
  def credit_card_on_file(credit_card)
    credit_card_mask(credit_card) ||
    credit_card_placeholder
  end

  def credit_card_mask(credit_card)
    credit_card.present? && "**** #{credit_card.last4}"
  end

  def credit_card_placeholder
    'None'
  end
end

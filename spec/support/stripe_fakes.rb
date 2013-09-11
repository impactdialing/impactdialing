module StripeFakes
  def self.valid_cards
    {
      visa: ['4242424242424242', '4012888888881881'],
      master_card: ['5555555555554444', '5105105105105100'],
      american_express: ['378282246310005', '371449635398431'],
      discover: ['6011111111111117', '6011000990139424'],
      diners_club: ['30569309025904', '38520000023237'],
      jcb: ['3530111333300000', '3566002020360505']
    }
  end

  def self.bad_address_and_zip
    '4000000000000010'
  end

  def self.bad_address
    '4000000000000028'
  end

  def self.bad_zip
    '4000000000000036'
  end

  def self.bad_cvc
    '4000000000000101'
  end

  def self.not_chargeable
    '4000000000000341'
  end

  def self.declined
    '4000000000000002'
  end

  def self.incorrect_cvc_code
    '4000000000000127'
  end

  def self.expired_card
    '4000000000000069'
  end

  def self.processing_error
    '4000000000000119'
  end
end
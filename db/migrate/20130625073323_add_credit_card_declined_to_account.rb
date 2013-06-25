class AddCreditCardDeclinedToAccount < ActiveRecord::Migration
  def change
    add_column :accounts, :credit_card_declined, :boolean, default: false
  end
end

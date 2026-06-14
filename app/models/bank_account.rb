class BankAccount < ApplicationRecord
  has_many :transactions, dependent: :destroy

  monetize :balance_cents, with_currency: :eur

  validates :iban, presence: true
  validates :bic, presence: true
  validates :balance_cents, numericality: { greater_than_or_equal_to: 0 }

  def sufficient_funds?(amount_cents)
    balance_cents >= amount_cents
  end
end

class Transaction < ApplicationRecord
  belongs_to :bank_account

  monetize :amount_cents, with_currency: :eur

  validates :counterparty_name, presence: true
  validates :counterparty_iban, presence: true
  validates :counterparty_bic, presence: true
  validates :amount_cents, numericality: { greater_than: 0 }
  validates :description, presence: true
end

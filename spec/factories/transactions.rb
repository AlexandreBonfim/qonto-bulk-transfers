FactoryBot.define do
  factory :transaction do
    association :bank_account
    counterparty_name { "Elon Greed Musk" }
    counterparty_iban { "EE383680981021245685" }
    counterparty_bic { "CRLYFRPPTOU" }
    amount_cents { 1_450 }  # 14.50 EUR
    amount_currency { "EUR" }
    description { "Wonderland/4410" }
  end
end

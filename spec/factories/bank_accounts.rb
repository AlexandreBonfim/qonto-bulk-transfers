FactoryBot.define do
  factory :bank_account do
    organization_name { "SpaceX" }
    balance_cents { 10_000_000 }  # 100,000 EUR
    iban { "FR10474608000002006107XXXXX" }
    bic { "OIVUSCLQXXX" }
  end
end

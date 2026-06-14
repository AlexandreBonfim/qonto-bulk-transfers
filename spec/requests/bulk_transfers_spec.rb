require "rails_helper"

RSpec.describe "POST /api/v1/transfers/bulk", type: :request do
  let!(:account) { create(:bank_account, balance_cents: 10_000_000) }

  let(:valid_payload) do
    {
      organization_bic: account.bic,
      organization_iban: account.iban,
      credit_transfers: [
        { amount: "14.5", currency: "EUR", counterparty_name: "Bip Bip",
          counterparty_bic: "CRLYFRPPTOU", counterparty_iban: "EE383680981021245685",
          description: "Wonderland/4410" },
        { amount: "61238", currency: "EUR", counterparty_name: "Wile E Coyote",
          counterparty_bic: "ZDRPLBQI", counterparty_iban: "DE9935420810036209081725212",
          description: "TeslaMotors/Invoice/12" },
        { amount: "999", currency: "EUR", counterparty_name: "Bugs Bunny",
          counterparty_bic: "RNJZNTMC", counterparty_iban: "FR0010009380540930414023042",
          description: "GoldenCarrot/" }
      ]
    }
  end

  let(:insufficient_funds_payload) do
    {
      organization_bic: account.bic,
      organization_iban: account.iban,
      credit_transfers: [
        { amount: "98234", currency: "EUR", counterparty_name: "Wile E Coyote",
          counterparty_bic: "ZDRPLBQI", counterparty_iban: "DE9935420810036209081725212",
          description: "Spacex/AJGRBX/32" },
        { amount: "8024.99", currency: "EUR", counterparty_name: "Bugs Bunny",
          counterparty_bic: "RNJZNTMC", counterparty_iban: "FR0010009380540930414023042",
          description: "DuckSeason/" }
      ]
    }
  end

  def post_bulk(payload)
    post "/api/v1/transfers/bulk",
      params: payload.to_json,
      headers: { "Content-Type" => "application/json" }
  end

  describe "201 Created" do
    it "returns 201 when funds are sufficient" do
      post_bulk(valid_payload)
      expect(response).to have_http_status(:created)
    end

    it "persists all transfers to the database" do
      expect { post_bulk(valid_payload) }
        .to change { Transaction.count }.by(3)
    end

    it "debits the correct amount from the account balance" do
      post_bulk(valid_payload)
      expect(account.reload.balance_cents).to eq(10_000_000 - 6_225_150)
    end
  end

  describe "422 insufficient funds" do
    it "returns 422" do
      post_bulk(insufficient_funds_payload)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns insufficient_funds error" do
      post_bulk(insufficient_funds_payload)
      expect(response.parsed_body["error"]).to eq("insufficient_funds")
    end

    it "does not persist any transactions" do
      expect { post_bulk(insufficient_funds_payload) }
        .not_to change { Transaction.count }
    end

    it "does not modify the balance" do
      expect { post_bulk(insufficient_funds_payload) }
        .not_to change { account.reload.balance_cents }
    end
  end

  describe "422 account not found" do
    it "returns 422 with account_not_found error" do
      post_bulk(valid_payload.merge(organization_iban: "UNKNOWN"))
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to eq("account_not_found")
    end
  end

  describe "422 invalid payload" do
    it "returns 422 when organization_bic is missing" do
      post_bulk(valid_payload.merge(organization_bic: nil))
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to eq("invalid_request")
    end

    it "returns 422 when credit_transfers is missing" do
      post_bulk(valid_payload.except(:credit_transfers))
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 422 when amount is invalid" do
      bad = valid_payload.deep_dup
      bad[:credit_transfers][0][:amount] = "not_a_number"
      post_bulk(bad)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 422 when currency is not EUR" do
      bad = valid_payload.deep_dup
      bad[:credit_transfers][0][:currency] = "USD"
      post_bulk(bad)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  # NOTE: Concurrency testing is not performed at the request spec level.
  #
  # RSpec request specs share a single Rails integration session and response
  # object, making them non-thread-safe. Spawning threads that call `post` here
  # results in both threads reading the same `response` object, causing
  # unpredictable 404s rather than real concurrent HTTP behaviour.
  #
  # True concurrency is tested at the command layer instead:
  # see spec/contexts/bulk_transfers/commands/persist_transfers_concurrency_spec.rb
  #
  # In production with PostgreSQL, you could also verify this end-to-end by
  # spinning up a real Puma server in the test suite and hitting it with
  # Net::HTTP from multiple threads. Overkill for SQLite
end

require "rails_helper"

RSpec.describe BulkTransfers::Services::CreateBulkTransfer do
  let!(:account) { create(:bank_account, balance_cents: 10_000_000) }

  # sample1.json — total: 62,251.50 EUR = 6,225,150 cents — should PASS
  let(:sample1_params) do
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

  # sample2.json — total: 106,482.16 EUR = 10,648,216 cents — should FAIL
  let(:sample2_params) do
    {
      organization_bic: account.bic,
      organization_iban: account.iban,
      credit_transfers: [
        { amount: "23.17", currency: "EUR", counterparty_name: "Bip Bip",
          counterparty_bic: "CRLYFRPPTOU", counterparty_iban: "EE383680981021245685",
          description: "Neverland/6318" },
        { amount: "98234", currency: "EUR", counterparty_name: "Wile E Coyote",
          counterparty_bic: "ZDRPLBQI", counterparty_iban: "DE9935420810036209081725212",
          description: "Spacex/AJGRBX/32" },
        { amount: "8024.99", currency: "EUR", counterparty_name: "Bugs Bunny",
          counterparty_bic: "RNJZNTMC", counterparty_iban: "FR0010009380540930414023042",
          description: "DuckSeason/" },
        { amount: "200", currency: "EUR", counterparty_name: "Daffy Duck",
          counterparty_bic: "DDFCNLAM", counterparty_iban: "NL24ABNA5055036109",
          description: "RabbitSeason/" }
      ]
    }
  end

  describe ".call" do
    context "happy path — sample1, sufficient funds" do
      it "returns success" do
        expect(described_class.call(sample1_params)).to be_success
      end

      it "creates 3 transaction records" do
        expect { described_class.call(sample1_params) }
          .to change { Transaction.count }.by(3)
      end

      it "debits the correct total from the balance" do
        described_class.call(sample1_params)
        expect(account.reload.balance_cents).to eq(10_000_000 - 6_225_150)
      end
    end

    context "insufficient funds — sample2, exceeds balance" do
      it "returns failure with :insufficient_funds" do
        result = described_class.call(sample2_params)
        expect(result).to be_failure
        expect(result.error).to eq(:insufficient_funds)
      end

      it "creates no transactions" do
        expect { described_class.call(sample2_params) }
          .not_to change { Transaction.count }
      end

      it "does not modify the balance" do
        expect { described_class.call(sample2_params) }
          .not_to change { account.reload.balance_cents }
      end
    end

    context "account not found" do
      it "returns failure with :account_not_found" do
        result = described_class.call(sample1_params.merge(organization_iban: "UNKNOWN"))
        expect(result).to be_failure
        expect(result.error).to eq(:account_not_found)
      end
    end

    context "invalid request payload" do
      it "returns failure with :invalid_request when bic is missing" do
        result = described_class.call(sample1_params.merge(organization_bic: nil))
        expect(result).to be_failure
        expect(result.error).to eq(:invalid_request)
      end

      it "returns failure when credit_transfers is empty" do
        result = described_class.call(sample1_params.merge(credit_transfers: []))
        expect(result).to be_failure
        expect(result.error).to eq(:invalid_request)
      end

      it "returns failure when currency is not EUR" do
        bad = sample1_params[:credit_transfers].dup
        bad[0] = bad[0].merge(currency: "USD")
        result = described_class.call(sample1_params.merge(credit_transfers: bad))
        expect(result).to be_failure
        expect(result.error).to eq(:invalid_request)
      end
    end
  end
end

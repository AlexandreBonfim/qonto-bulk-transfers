require "rails_helper"

RSpec.describe BulkTransfers::Dto::BulkTransferRequest do
  let(:valid_params) do
    {
      organization_bic: "OIVUSCLQXXX",
      organization_iban: "FR10474608000002006107XXXXX",
      credit_transfers: [
        {
          amount: "14.5",
          currency: "EUR",
          counterparty_name: "Bip Bip",
          counterparty_bic: "CRLYFRPPTOU",
          counterparty_iban: "EE383680981021245685",
          description: "Wonderland/4410"
        },
        {
          amount: "999",
          currency: "EUR",
          counterparty_name: "Bugs Bunny",
          counterparty_bic: "RNJZNTMC",
          counterparty_iban: "FR0010009380540930414023042",
          description: "GoldenCarrot/"
        }
      ]
    }
  end

  subject(:request) { described_class.new(valid_params) }

  describe "validations" do
    it "is valid with correct params" do
      expect(request).to be_valid
    end

    it "is invalid without organization_bic" do
      request = described_class.new(valid_params.merge(organization_bic: nil))
      expect(request).not_to be_valid
      expect(request.errors[:organization_bic]).to include("can't be blank")
    end

    it "is invalid without organization_iban" do
      request = described_class.new(valid_params.merge(organization_iban: nil))
      expect(request).not_to be_valid
    end

    it "is invalid without credit_transfers" do
      request = described_class.new(valid_params.merge(credit_transfers: nil))
      expect(request).not_to be_valid
    end

    it "is invalid with empty credit_transfers array" do
      request = described_class.new(valid_params.merge(credit_transfers: []))
      expect(request).not_to be_valid
    end

    it "is invalid when a transfer is missing amount" do
      bad = valid_params[:credit_transfers].dup
      bad[0] = bad[0].merge(amount: nil)
      request = described_class.new(valid_params.merge(credit_transfers: bad))
      expect(request).not_to be_valid
      expect(request.errors[:credit_transfers].join).to include("amount")
    end

    it "is invalid when amount has more than 2 decimal places" do
      bad = valid_params[:credit_transfers].dup
      bad[0] = bad[0].merge(amount: "14.999")
      request = described_class.new(valid_params.merge(credit_transfers: bad))
      expect(request).not_to be_valid
    end

    it "is invalid when currency is not EUR" do
      bad = valid_params[:credit_transfers].dup
      bad[0] = bad[0].merge(currency: "USD")
      request = described_class.new(valid_params.merge(credit_transfers: bad))
      expect(request).not_to be_valid
      expect(request.errors[:credit_transfers].join).to include("unsupported currency")
    end
  end

  describe "#total_cents" do
    it "sums all amounts as integer cents without floating point errors" do
      # 14.5 EUR + 999 EUR = 1013.5 EUR = 101_350 cents
      expect(request.total_cents).to eq(101_350)
    end

    it "handles whole integer amounts correctly" do
      request = described_class.new(valid_params.merge(
        credit_transfers: [ {
          amount: "61238", currency: "EUR", counterparty_name: "X",
          counterparty_bic: "Y", counterparty_iban: "Z", description: "D"
        } ]
      ))
      expect(request.total_cents).to eq(6_123_800)
    end
  end
end

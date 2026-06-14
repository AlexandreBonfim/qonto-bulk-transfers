require "rails_helper"

RSpec.describe BulkTransfers::Commands::ValidateAccount do
  let!(:account) { create(:bank_account) }

  let(:matching_request) do
    BulkTransfers::Dto::BulkTransferRequest.new(
      organization_iban: account.iban,
      organization_bic: account.bic,
      credit_transfers: []
    )
  end

  let(:unknown_request) do
    BulkTransfers::Dto::BulkTransferRequest.new(
      organization_iban: "UNKNOWN_IBAN",
      organization_bic: "UNKNOWN_BIC",
      credit_transfers: []
    )
  end

  describe ".call" do
    context "when account exists" do
      it "returns success" do
        expect(described_class.call(matching_request)).to be_success
      end

      it "returns the account as payload" do
        result = described_class.call(matching_request)
        expect(result.payload).to eq(account)
      end
    end

    context "when account does not exist" do
      it "returns failure" do
        expect(described_class.call(unknown_request)).to be_failure
      end

      it "returns :account_not_found error" do
        result = described_class.call(unknown_request)
        expect(result.error).to eq(:account_not_found)
      end
    end
  end
end

require "rails_helper"

RSpec.describe BankAccount, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:transactions).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:iban) }
    it { is_expected.to validate_presence_of(:bic) }
    it { is_expected.to validate_numericality_of(:balance_cents).is_greater_than_or_equal_to(0) }
  end

  describe "#sufficient_funds?" do
    let(:account) { build(:bank_account, balance_cents: 10_000) }

    it "returns true when balance covers the amount" do
      expect(account.sufficient_funds?(9_999)).to be true
    end

    it "returns true when balance exactly matches the amount" do
      expect(account.sufficient_funds?(10_000)).to be true
    end

    it "returns false when balance is insufficient" do
      expect(account.sufficient_funds?(10_001)).to be false
    end
  end
end

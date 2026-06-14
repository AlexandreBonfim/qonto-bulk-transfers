require "rails_helper"

RSpec.describe Transaction, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:bank_account) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:counterparty_name) }
    it { is_expected.to validate_presence_of(:counterparty_iban) }
    it { is_expected.to validate_presence_of(:counterparty_bic) }
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_numericality_of(:amount_cents).is_greater_than(0) }
  end
end

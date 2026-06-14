module BulkTransfers
  module Dto
    class BulkTransferRequest
      include ActiveModel::Validations

      AMOUNT_FORMAT = /\A\d+(\.\d{1,2})?\z/
      SUPPORTED_CURRENCY = "EUR"

      attr_reader :organization_bic, :organization_iban, :credit_transfers

      validates :organization_bic, presence: true
      validates :organization_iban, presence: true
      validates :credit_transfers, presence: true
      validate :credit_transfers_must_be_valid, if: -> { credit_transfers.present? }

      def initialize(params)
        @organization_bic = params[:organization_bic]
        @organization_iban = params[:organization_iban]
        @credit_transfers = params[:credit_transfers]
      end

      def total_cents
        credit_transfers.sum { |t| Money.from_amount(t[:amount].to_d, t[:currency]).fractional }
      end

      private

      def credit_transfers_must_be_valid
        unless credit_transfers.is_a?(Array)
          errors.add(:credit_transfers, "must be an array")
          return
        end

        credit_transfers.each_with_index do |transfer, index|
          validate_transfer(transfer, index)
        end
      end

      def validate_transfer(transfer, index)
        %i[amount currency counterparty_bic counterparty_iban counterparty_name description].each do |field|
          if transfer[field].blank?
            errors.add(:credit_transfers, "entry #{index + 1} is missing #{field}")
          end
        end

        if transfer[:amount].present? && !AMOUNT_FORMAT.match?(transfer[:amount].to_s)
          errors.add(:credit_transfers, "entry #{index + 1} has invalid amount '#{transfer[:amount]}'")
        end

        if transfer[:currency].present? && transfer[:currency] != SUPPORTED_CURRENCY
          errors.add(:credit_transfers, "entry #{index + 1} has unsupported currency '#{transfer[:currency]}'")
        end
      end
    end
  end
end

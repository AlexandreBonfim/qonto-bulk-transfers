module BulkTransfers
  module Commands
    class PersistTransfers < BaseCommand
      def initialize(account, request)
        @account = account
        @request = request
      end

      def call
        ApplicationRecord.transaction do
          locked_account = BankAccount.lock.find(@account.id)

          unless locked_account.sufficient_funds?(@request.total_cents)
            return ServiceResult.failure(:insufficient_funds)
          end

          @request.credit_transfers.each do |transfer|
            unless transfer[:currency] == BulkTransfers::Dto::BulkTransferRequest::SUPPORTED_CURRENCY
              return ServiceResult.failure(:unsupported_currency, "Unsupported currency '#{transfer[:currency]}'")
            end

            locked_account.transactions.create!(
              counterparty_name: transfer[:counterparty_name],
              counterparty_iban: transfer[:counterparty_iban],
              counterparty_bic: transfer[:counterparty_bic],
              amount_cents: Money.from_amount(transfer[:amount].to_d, transfer[:currency]).fractional,
              amount_currency: transfer[:currency],
              description: transfer[:description]
            )
          end

          locked_account.update!(
            balance_cents: locked_account.balance_cents - @request.total_cents
          )
        end

        ServiceResult.success
      rescue ActiveRecord::RecordInvalid, Money::Currency::UnknownCurrency => e
        ServiceResult.failure(:transaction_invalid, e.message)
      end
    end
  end
end

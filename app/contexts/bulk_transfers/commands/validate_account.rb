module BulkTransfers
  module Commands
    class ValidateAccount < BaseCommand
      def initialize(request)
        @request = request
      end

      def call
        account = BankAccount.find_by(
          iban: @request.organization_iban,
          bic: @request.organization_bic
        )

        if account.nil?
          ServiceResult.failure(:account_not_found)
        else
          ServiceResult.success(account)
        end
      end
    end
  end
end

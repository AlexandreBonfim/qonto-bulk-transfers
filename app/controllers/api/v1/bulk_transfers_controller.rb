module Api
  module V1
    class BulkTransfersController < ApplicationController
      def create
        result = BulkTransfers::Services::CreateBulkTransfer.call(bulk_transfer_params)

        if result.success?
          head :created
        else
          render json: error_response(result), status: :unprocessable_content
        end
      end

      private

      def bulk_transfer_params
        params.permit(
          :organization_bic,
          :organization_iban,
          credit_transfers: [
            :amount,
            :currency,
            :counterparty_bic,
            :counterparty_iban,
            :counterparty_name,
            :description
          ]
        ).to_h.with_indifferent_access
      end

      def error_response(result)
        { error: result.error, message: result.error_message }
      end
    end
  end
end

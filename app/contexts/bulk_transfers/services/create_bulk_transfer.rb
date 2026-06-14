module BulkTransfers
  module Services
    class CreateBulkTransfer
      def self.call(params)
        new(params).call
      end

      def initialize(params)
        @params = params
      end

      def call
        request = Dto::BulkTransferRequest.new(@params)

        unless request.valid?
          return ServiceResult.failure(:invalid_request, request.errors.full_messages.join(", "))
        end

        result = Commands::ValidateAccount.call(request)
        return result if result.failure?

        Commands::PersistTransfers.call(result.payload, request)
      end
    end
  end
end

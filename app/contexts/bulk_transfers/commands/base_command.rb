module BulkTransfers
  module Commands
    class BaseCommand
      def self.call(...)
        new(...).call
      end
    end
  end
end

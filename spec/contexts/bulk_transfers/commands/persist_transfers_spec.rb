require "rails_helper"

RSpec.describe BulkTransfers::Commands::PersistTransfers do
  let!(:account) { create(:bank_account, balance_cents: 10_000_000) }

  let(:credit_transfers) do
    [
      {
        amount: "14.5",
        currency: "EUR",
        counterparty_name: "Bip Bip",
        counterparty_bic: "CRLYFRPPTOU",
        counterparty_iban: "EE383680981021245685",
        description: "Wonderland/4410"
      },
      {
        amount: "61238",
        currency: "EUR",
        counterparty_name: "Wile E Coyote",
        counterparty_bic: "ZDRPLBQI",
        counterparty_iban: "DE9935420810036209081725212",
        description: "TeslaMotors/Invoice/12"
      }
    ]
  end

  let(:request) do
    BulkTransfers::Dto::BulkTransferRequest.new(
      organization_iban: account.iban,
      organization_bic: account.bic,
      credit_transfers: credit_transfers
    )
  end

  describe ".call" do
    context "when funds are sufficient" do
      it "returns success" do
        expect(described_class.call(account, request)).to be_success
      end

      it "creates a transaction record for each transfer" do
        expect { described_class.call(account, request) }
          .to change { Transaction.count }.by(2)
      end

      it "debits the correct total from the balance" do
        # 14.5 EUR + 61,238 EUR = 61,252.5 EUR = 6,125,250 cents
        expect { described_class.call(account, request) }
          .to change { account.reload.balance_cents }.by(-6_125_250)
      end

      it "stores amount in cents without floating point errors" do
        described_class.call(account, request)
        expect(account.transactions.first.amount_cents).to eq(1_450)
      end
    end

    context "when funds are insufficient" do
      let!(:account) { create(:bank_account, balance_cents: 100) }

      it "returns failure" do
        expect(described_class.call(account, request)).to be_failure
      end

      it "returns :insufficient_funds error" do
        result = described_class.call(account, request)
        expect(result.error).to eq(:insufficient_funds)
      end

      it "does not create any transactions" do
        expect { described_class.call(account, request) }
          .not_to change { Transaction.count }
      end

      it "does not modify the balance" do
        expect { described_class.call(account, request) }
          .not_to change { account.reload.balance_cents }
      end
    end

    context "when currency is not EUR" do
      let(:credit_transfers) do
        [
          {
            amount: "14.5",
            currency: "USD",
            counterparty_name: "Bip Bip",
            counterparty_bic: "CRLYFRPPTOU",
            counterparty_iban: "EE383680981021245685",
            description: "Wonderland/4410"
          }
        ]
      end

      it "does not create any transactions" do
        expect { described_class.call(account, request) rescue nil }
          .not_to change { Transaction.count }
      end
    end

    context "atomicity" do
      it "rolls back all inserts if balance update fails" do
        allow_any_instance_of(BankAccount)
          .to receive(:update!)
          .and_raise(ActiveRecord::StatementInvalid)

        expect { described_class.call(account, request) rescue nil }
          .not_to change { Transaction.count }
      end

      it "rolls back all inserts if balance update fails midway" do
        # Simulate a crash after transfers are inserted but before balance is updated
        allow_any_instance_of(BankAccount)
          .to receive(:update!)
          .and_raise(ActiveRecord::StatementInvalid)
    
        expect { described_class.call(account, request) rescue nil }
          .not_to change { Transaction.count }
    
        # Balance must be untouched — no partial state committed
        expect(account.reload.balance_cents).to eq(10_000_000)
      end
    
      it "rolls back if the connection drops mid-transaction" do
        # Simulate network glitch / connection drop mid-transaction
        call_count = 0
        allow_any_instance_of(BankAccount)
          .to receive(:update!) do
            call_count += 1
            raise ActiveRecord::ConnectionFailed, "connection lost" if call_count == 1
          end
    
        expect { described_class.call(account, request) rescue nil }
          .not_to change { Transaction.count }
    
        expect(account.reload.balance_cents).to eq(10_000_000)
      end
    
      it "rolls back if only some transfers are inserted before crash" do
        # Simulate crash after first insert but before second
        insert_count = 0
        allow_any_instance_of(ActiveRecord::Associations::CollectionProxy)
          .to receive(:create!) do |*args, **kwargs|
            insert_count += 1
            raise ActiveRecord::StatementInvalid, "server crashed" if insert_count == 2
            # First insert succeeds, second raises
            Transaction.create!(*args, **kwargs)
          end
    
        expect { described_class.call(account, request) rescue nil }
          .not_to change { Transaction.count }
    
        expect(account.reload.balance_cents).to eq(10_000_000)
      end
    end
  end
end

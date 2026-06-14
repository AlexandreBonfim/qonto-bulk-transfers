# spec/contexts/bulk_transfers/commands/persist_transfers_concurrency_spec.rb
require "rails_helper"

RSpec.describe BulkTransfers::Commands::PersistTransfers, :concurrency do
  self.use_transactional_tests = false

  after do
    Transaction.delete_all
    BankAccount.delete_all
  end

  it "prevents double-spending under concurrent requests" do
    # Account has exactly 80,000 EUR.
    # Two simultaneous requests each try to spend 80,000 EUR.
    # Without SELECT FOR UPDATE both would read the same balance,
    # both pass the funds check, and both succeed — overdraft.
    # With the row lock only one proceeds; the second waits,
    # re-reads the updated balance (0), and is rejected.
    account = BankAccount.create!(
      organization_name: "ACME Corp",
      balance_cents: 8_000_000,
      iban: "FR10474608000002006107XXXXX",
      bic: "OIVUSCLQXXX"
    )

    request = BulkTransfers::Dto::BulkTransferRequest.new(
      organization_iban: account.iban,
      organization_bic: account.bic,
      credit_transfers: [
        {
          amount: "80000",
          currency: "EUR",
          counterparty_name: "Big Spender",
          counterparty_bic: "ZDRPLBQI",
          counterparty_iban: "DE9935420810036209081725212",
          description: "Salary run"
        }
      ]
    )

    results = []
    mutex = Mutex.new

    threads = Array.new(2) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          result = BulkTransfers::Commands::PersistTransfers.call(account, request)
          mutex.synchronize { results << result }
        end
      end
    end

    threads.each(&:join)

    expect(results.count(&:success?)).to eq(1)
    expect(results.count(&:failure?)).to eq(1)
    expect(results.find(&:failure?).error).to eq(:insufficient_funds)
    expect(account.reload.balance_cents).to eq(0)
    expect(Transaction.count).to eq(1)
  end
end

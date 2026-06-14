# Qonto Bulk Transfers

A Rails API service to process bulk transfer requests from a single Qonto account.

## How to run

**Without Docker:**
```bash
bundle install
bin/rails server
```

**With Docker:**
```bash
docker compose up
```

The provided `qonto_accounts.sqlite` is already in `db/` and used as the development database. No migrations needed.

### Try it with the sample payloads

```bash
# sample1.json — should succeed (total: 62,251.50 EUR, balance: 100,000 EUR)
curl -X POST http://localhost:3000/api/v1/transfers/bulk \
  -H "Content-Type: application/json" \
  -d @challenge-source/sample1.json
# → 201 Created

# sample2.json — should be denied (total: 106,482.16 EUR, exceeds balance)
curl -X POST http://localhost:3000/api/v1/transfers/bulk \
  -H "Content-Type: application/json" \
  -d @challenge-source/sample2.json
# → 422 Unprocessable Entity
```

## How to run the tests

```bash
bundle exec rspec
```

## API

### `POST /api/v1/transfers/bulk`

**Request body:**
```json
{
  "organization_bic": "OIVUSCLQXXX",
  "organization_iban": "FR10474608000002006107XXXXX",
  "credit_transfers": [
    {
      "amount": "14.5",
      "currency": "EUR",
      "counterparty_name": "Bip Bip",
      "counterparty_bic": "CRLYFRPPTOU",
      "counterparty_iban": "EE383680981021245685",
      "description": "Wonderland/4410"
    }
  ]
}
```

**Responses:**

| Status | Meaning |
|--------|---------|
| `201 Created` | Transfers persisted, balance debited |
| `422 Unprocessable Entity` | Insufficient funds, unknown account or invalid payload |

**Error response body:**
```json
{ "error": "insufficient_funds", "message": "insufficient_funds" }
{ "error": "account_not_found", "message": "account_not_found" }
{ "error": "invalid_request", "message": "Organization bic can't be blank" }
```
## Interactive API documentation

The API is documented with [rswag](https://github.com/rswag/rswag) and available as an interactive Swagger UI:

```
http://localhost:3000/api-docs
```

From there you can explore the full contract and execute requests directly in the browser without needing curl or Postman. The spec is auto-generated from the request specs, keeping documentation and implementation always in sync.

## Architecture

The project follows Qonto's **Contexts, Services and Commands** [pattern](https://medium.com/qonto-way/navigating-complexity-at-scale-qontos-monolithic-domain-driven-design-journey-76a2a08989fa).

```
app/
  contexts/
    bulk_transfers/
      services/
        create_bulk_transfer.rb     ← public interface of the context
      commands/
        validate_account.rb         ← finds account by IBAN + BIC
        persist_transfers.rb        ← locks row, validates funds, inserts, debits
      dto/
        bulk_transfer_request.rb    ← input validation via ActiveModel
  controllers/
    api/v1/
      bulk_transfers_controller.rb  ← thin, delegates everything to the service
  models/
    bank_account.rb
    transaction.rb
  lib/
    service_result.rb               ← simple value object for flow control
```

The **service** is the only public interface — anything outside this context calls `CreateBulkTransfer.call(params)` and nothing else. **Commands** are private steps the service orchestrates. Each returns a `ServiceResult`, keeping flow control out of exceptions and nested conditionals.

## Key design decisions

### Money in cents, never floats

All amounts are converted to integer cents immediately on input using `Money.from_amount` with `BigDecimal` internally:

```ruby
Money.from_amount("14.5".to_d, "EUR").fractional  # => 1450
```

Floats are never used. `0.1 + 0.2` is `0.30000000000000004` in floating point unacceptable in a financial system. Everything is stored as `INTEGER` cents in the database.

### Atomic transactions — crash safety

All writes (transaction inserts + balance update) happen inside a single `ActiveRecord::Base.transaction` block. If the process crashes between inserting transfers and updating the balance, the entire operation rolls back. No partial states are ever committed to the database.

### Pessimistic row locking — concurrency safety

With multiple load-balanced instances, two simultaneous requests for the same account could both read the same balance, both pass the funds check, and both proceed resulting in an overdraft.

The fix is a row-level lock acquired at the start of the transaction:

```ruby
ActiveRecord::Base.transaction do
  locked_account = BankAccount.lock.find(account.id)  # SELECT ... FOR UPDATE
  # Second request blocks here until the first commits.
  # It then re-reads the updated balance before proceeding.
end
```

The balance check happens inside the lock not before acquiring it. This guarantees the check and the debit are atomic.

### Input validation at the boundary

The `BulkTransferRequest` DTO validates the incoming payload before it touches the domain. Presence of required fields, amount format (max 2 decimal places), and currency (EUR only). This keeps models clean and makes error messages explicit.

## Assumptions

- Currency is always EUR. Non-EUR transfers are rejected at the DTO layer.
- `organization_bic` + `organization_iban` together uniquely identify an account.
- `amount` is always a positive string with at most 2 decimal places, as stated in the spec.
- The provided `qonto_accounts.sqlite` uses a `transactions` table. The PDF spec refers to `transfers`. We follow the actual database.

## Issues faced

**SQLite concurrency limitations**: SQLite does not support true concurrent writes the way PostgreSQL does. Testing the `SELECT FOR UPDATE` the concurrency spec to the command layer rather than the request layer. In production this would not be an issue since PostgreSQL handles concurrent connections natively.

**Amount precision**: The `amount` field arrives as a string with optional decimals. Using `Float` would risk silent precision loss (`14.5.to_f * 100 = 1449.9999...`). We use `Money.from_amount` with `BigDecimal` internally to guarantee exact cent conversion.

## Potential improvements

**Idempotency**: A network timeout may cause the client to retry a request that already succeeded, resulting in duplicate salary payments. The fix is an `Idempotency-Key` header: the server stores a hash of the request and returns the cached response on retry. Not implemented as it was not required by the spec, but it would be the first thing I'd add before going to production.

**PostgreSQL in production**: The solution is designed for PostgreSQL (`SELECT FOR UPDATE` works identically). SQLite is used locally per the challenge instructions. The only change needed is the adapter in `database.yml`.

**Audit trail**: A production banking system would keep an immutable ledger of every balance change: who requested it, when, and what the before/after balance was. This could be an `account_ledger` table updated inside the same transaction.

**Advisory locks**: For even finer-grained concurrency control on PostgreSQL, `pg_try_advisory_xact_lock` could replace row-level locking, avoiding contention on the `bank_accounts` table entirely.

**Docker setup**: A `Dockerfile` and `docker-compose.yml` are included for reviewers who prefer not to install Ruby locally. When switching to PostgreSQL, the compose file would spin up both the app and the database in one command.

**Observability**: A production banking system needs full visibility into what's happening at runtime. I'd add three layers:

- **Structured logging**: each bulk transfer request logged with a unique `request_id`, the account IBAN, total amount, number of transfers, and outcome (success/failure with reason). Using a structured format like JSON makes it trivially searchable.

- **Metrics**: counters and histograms for request volume, failure reasons (insufficient funds vs account not found vs invalid payload) and processing latency. Useful for alerting on unusual rejection spikes which could indicate a bug or a client issue.

- **Alerting**: if the insufficient funds rejection rate spikes unexpectedly or if transaction counts drop to zero during business hours **something is wrong**. These alerts are only possible if the metrics layer is in place.

## Feedback - PDF questions

1. How much time did you spend completing this test?
    - **3hrs and 24 min**
2. How proud are you of your work?
    - **Fairly proud**
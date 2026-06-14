require "swagger_helper"

RSpec.describe "Bulk Transfers API", type: :request do
  path "/api/v1/transfers/bulk" do
    post "Creates a bulk transfer" do
      tags "Bulk Transfers"
      consumes "application/json"
      produces "application/json"

      parameter name: :payload, in: :body, schema: {
        type: :object,
        required: %w[organization_bic organization_iban credit_transfers],
        properties: {
          organization_bic: {
            type: :string,
            example: "OIVUSCLQXXX",
            description: "BIC of the Qonto customer's organization"
          },
          organization_iban: {
            type: :string,
            example: "FR10474608000002006107XXXXX",
            description: "IBAN of the Qonto customer's organization"
          },
          credit_transfers: {
            type: :array,
            items: {
              type: :object,
              required: %w[amount currency counterparty_bic counterparty_iban counterparty_name description],
              properties: {
                amount: {
                  type: :string,
                  example: "14.5",
                  description: "Amount in EUR, max 2 decimal places"
                },
                currency: {
                  type: :string,
                  example: "EUR",
                  description: "Always EUR"
                },
                counterparty_name: {
                  type: :string,
                  example: "Bip Bip"
                },
                counterparty_bic: {
                  type: :string,
                  example: "CRLYFRPPTOU"
                },
                counterparty_iban: {
                  type: :string,
                  example: "EE383680981021245685"
                },
                description: {
                  type: :string,
                  example: "Wonderland/4410"
                }
              }
            }
          }
        }
      }

      response "201", "transfers created successfully" do
        let(:payload) do
          {
            organization_bic: "OIVUSCLQXXX",
            organization_iban: "FR10474608000002006107XXXXX",
            credit_transfers: [
              {
                amount: "14.5",
                currency: "EUR",
                counterparty_name: "Bip Bip",
                counterparty_bic: "CRLYFRPPTOU",
                counterparty_iban: "EE383680981021245685",
                description: "Wonderland/4410"
              }
            ]
          }
        end

        before do
          BankAccount.create!(
            organization_name: "ACME Corp",
            balance_cents: 10_000_000,
            iban: "FR10474608000002006107XXXXX",
            bic: "OIVUSCLQXXX"
          )
        end

        run_test!
      end

      response "422", "insufficient funds" do
        schema type: :object,
          properties: {
            error: { type: :string, example: "insufficient_funds" },
            message: { type: :string, example: "insufficient_funds" }
          }

        let(:payload) do
          {
            organization_bic: "OIVUSCLQXXX",
            organization_iban: "FR10474608000002006107XXXXX",
            credit_transfers: [
              {
                amount: "99999999",
                currency: "EUR",
                counterparty_name: "Bip Bip",
                counterparty_bic: "CRLYFRPPTOU",
                counterparty_iban: "EE383680981021245685",
                description: "Wonderland/4410"
              }
            ]
          }
        end

        before do
          BankAccount.create!(
            organization_name: "ACME Corp",
            balance_cents: 100,
            iban: "FR10474608000002006107XXXXX",
            bic: "OIVUSCLQXXX"
          )
        end

        run_test!
      end

      response "422", "account not found" do
        schema type: :object,
          properties: {
            error: { type: :string, example: "account_not_found" },
            message: { type: :string, example: "account_not_found" }
          }

        let(:payload) do
          {
            organization_bic: "UNKNOWN",
            organization_iban: "UNKNOWN",
            credit_transfers: []
          }
        end

        run_test!
      end

      response "422", "invalid request payload" do
        schema type: :object,
          properties: {
            error: { type: :string, example: "invalid_request" },
            message: { type: :string, example: "Organization bic can't be blank" }
          }

        let(:payload) do
          {
            organization_bic: nil,
            organization_iban: "FR10474608000002006107XXXXX",
            credit_transfers: []
          }
        end

        run_test!
      end
    end
  end
end
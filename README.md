# ModelRegistry: Decentralized AI Model Ownership & Licensing

**ModelRegistry** is a high-performance, production-grade Clarity 2.0 smart contract deployed on the Stacks blockchain. It provides a standardized, decentralized framework for the registration, metadata management, commercialization, and licensing of Artificial Intelligence models. By anchoring model provenance and ownership to a secure blockchain layer, it enables a trustless economy for AI developers and consumers.

---

## Table of Contents

1. Project Vision and Overview
2. Core Technical Features
3. Detailed Functional Specification: Private Functions
4. Detailed Functional Specification: Public Functions
5. Detailed Functional Specification: Read-Only Functions
6. Data Schema and Constants
7. Error Code Reference
8. Security Architecture and Governance
9. Full MIT License
10. Contribution Guidelines

---

## Project Vision and Overview

As AI models become increasingly valuable assets, the need for a transparent and immutable registry grows. **ModelRegistry** serves as the backbone for a decentralized AI marketplace. It allows researchers to timestamp their work, companies to acquire IP through atomic swaps, and developers to access state-of-the-art weights via programmatic licensing.

The contract is designed with a "Security-First" philosophy, incorporating circuit breakers, strict access controls, and a platform fee cap to protect all participants in the ecosystem.

---

## Core Technical Features

* **Immutable Provenance:** Every model registration includes a SHA-256 hash, ensuring that the version of the model used corresponds exactly to the version registered.
* **Granular Monetization:** Supports both "Full Buyout" (Ownership Transfer) and "Usage Licensing" (Access Rights).
* **Reputation Layer:** A license-gated rating system prevents sybil attacks and ensures that only verified users can influence a model's score.
* **Administrative Circuit Breaker:** The ability to pause the contract ensures that user funds can be protected during unforeseen network events or upgrades.
* **Atomic Settlements:** Payment and ownership/license transfer occur in a single, atomic transaction—eliminating counterparty risk.

---

## Detailed Functional Specification: Private Functions

Private functions are internal helper methods that encapsulate logic used across multiple public entry points. They are not callable by external users.

### is-owner
* **Parameters:** `(model-id uint)`, `(caller principal)`
* **Logic:** Retrieves the model from the `models` map and compares the stored `owner` principal against the `caller`.
* **Usage:** Used to gate metadata updates, listing, and price setting.

### check-not-paused
* **Parameters:** None
* **Logic:** Asserts that the `is-paused` data variable is currently `false`.
* **Usage:** This is the contract's primary "Modifier." It is called at the beginning of every state-changing public function to ensure the contract is operational.

### calculate-fee
* **Parameters:** `(amount uint)`
* **Logic:** Multiplies the transaction `amount` by the `platform-fee` and divides by 100.
* **Usage:** Standardizes how the administrative commission is calculated for both full purchases and licensing fees.

---

## Detailed Functional Specification: Public Functions

These are the primary entry points for users and the contract administrator.

### Administrative Functions

* **set-paused:** Allows the `contract-owner` to toggle the operational status of the contract. Essential for emergency management.
* **set-fee:** Allows the `contract-owner` to set the percentage of each sale taken as a platform fee. This function includes a hard-coded check to ensure the fee never exceeds 10%.

### Registration and Updates

* **register-model:** Initializes a new entry in the registry. It assigns a unique ID, sets the sender as the owner, and stores the model's hash and description.
* **update-model:** Allows the current owner to modify the description or the hash. This is intended for model versioning and fixing metadata errors.

### Marketplace Operations

* **list-model:** Sets a sale price and marks the `listed` status as `true`. Only listed models can be purchased through `purchase-model`.
* **delist-model:** Sets the `listed` status to `false`. This prevents users from initiating a purchase of the model.
* **set-license-price:** Defines the cost for a user to acquire a license. Unlike a full purchase, setting this price does not automatically list the model for ownership transfer.
* **purchase-model:** The most complex function in the contract. It handles the transfer of STX from the buyer to the seller (minus the platform fee), transfers the platform fee to the admin, and updates the ownership record.
* **purchase-license:** Transfers the license fee (minus platform commission) to the owner and records a permanent, valid license for the caller in the `licenses` map.

### Community Interaction

* **rate-model:** Accepts a `uint` from 1 to 5. It verifies that the user holds a valid license and has not previously rated this model. It then updates the aggregate `total-rating` and `rating-count` in the model's metadata.

---

## Detailed Functional Specification: Read-Only Functions

Read-only functions allow users and front-end applications to query the state of the blockchain without gas costs or transactions.

* **get-model-details:** Returns all metadata associated with a specific `model-id`, including ownership, price, and rating statistics.
* **get-license-details:** Checks the `licenses` map to see if a specific principal holds a valid license for a specific model ID and provides the block height of purchase.
* **get-user-rating:** Returns the specific rating (1-5) that a user gave to a specific model.
* **is-contract-paused:** Returns the current boolean state of the circuit breaker.
* **get-platform-fee:** Returns the current percentage fee applied to transactions.

---

## Data Schema and Constants

The contract utilizes three primary maps to maintain state:

1.  **models:** Keyed by `model-id`. Stores the structural data and commercial parameters of the AI asset.
2.  **licenses:** Keyed by a composite of `model-id` and `user`. Tracks access rights.
3.  **user-ratings:** Keyed by a composite of `model-id` and `user`. Ensures one vote per license holder.

**Constants:**
* `contract-owner`: Hard-coded to the principal that deploys the contract.
* `next-model-id`: A counter that increments with every successful registration.

---

## Error Code Reference

| Code | Name | Logic / Trigger |
| :--- | :--- | :--- |
| **u100** | `err-not-owner` | Caller is not the principal listed as the model owner. |
| **u101** | `err-model-exists` | Attempted to insert a model ID that is already taken. |
| **u102** | `err-model-not-found` | The requested ID does not exist in the map. |
| **u103** | `err-invalid-price` | Listing a model for u0 or an invalid amount. |
| **u106** | `err-paused` | The contract is currently disabled by the administrator. |
| **u107** | `err-unauthorized` | An administrative function was called by a non-admin. |
| **u108** | `err-already-rated` | The licensee attempted to submit a second rating. |
| **u109** | `err-invalid-rating` | The rating provided was outside the 1-5 range. |
| **u111** | `err-invalid-fee` | The administrator tried to set a fee higher than 10%. |

---

## Security Architecture and Governance

The **ModelRegistry** employs several layers of security:
1.  **Authorization Gating:** Every sensitive function checks `tx-sender` against the stored `owner` principal.
2.  **Fail-Safe Math:** Using Clarity’s native `uint` prevents overflow/underflow vulnerabilities.
3.  **Explicit Returns:** Every state change is wrapped in a `try!` or `unwrap!` to ensure atomic success or failure.
4.  **Ownership Reset:** Upon a full purchase, the model is automatically delisted and its price reset to zero. This prevents "double-sale" attacks or accidental sales at old prices by the new owner.

---

## Full MIT License

Copyright (c) 2026 AI Assistant & ModelRegistry Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

---

## Contribution Guidelines

We welcome community audits and feature proposals. To contribute:
1.  Ensure you have `Clarinet` installed for local testing.
2.  Maintain 100% test coverage for any new public functions.
3.  Adhere to the Clarity naming conventions (kebab-case for functions and variables).
4.  Submit your pull request against the `develop` branch for review.

---

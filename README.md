# HEALTHSHARE - Community Health Insurance Pool

## Overview

HEALTHSHARE is a blockchain-based **community health insurance system** designed to provide accessible healthcare to underserved populations. It ensures **transparent claims processing** and addresses **UN SDG 3: Good Health and Well-Being** by offering affordable health coverage options.

## Features

* Community-managed health insurance pools
* Member registration with customizable coverage types
* Automated premium calculation based on age, health score, and coverage level
* Premium payment tracking and recurring coverage validation
* Transparent medical claims submission, review, and approval process
* Healthcare provider registration and verification system
* Health risk assessments and scoring
* Emergency community health fund management
* Platform-wide statistics and monitoring

## Data Structures

* **health-members** – Member records including age, coverage, premiums, health score, and claim history
* **health-pools** – Insurance pools with balance, demographics, premium base, and coverage limits
* **medical-claims** – Claim records with status, provider, medical category, and review details
* **healthcare-providers** – Registered healthcare providers with license, specialization, and verification status
* **premium-payments** – Payment history with coverage periods and methods
* **risk-assessments** – Health assessments with risk score, metrics, and recommendations
* **emergency-fund** – Community health emergency fund with contributions and beneficiaries

## Key Constants

* **Coverage Types**: Basic, Standard, Premium, Emergency
* **Claim Status**: Submitted, Under Review, Approved, Denied, Paid
* **Medical Categories**: General, Emergency, Maternal, Chronic, Preventive, Dental, Mental
* **Time**: Monthly cycle (4320 blocks), Waiting Period (4 months), Claim Review (10 days)
* **Financials**: Min premium = 0.5 STX, Max claim = 500 STX, Admin fee = 3%

## Core Functions

### Member Management

* `join-health-pool(...)` – Register and join a pool
* `pay-premium(pool-id)` – Pay monthly premium

### Claims Processing

* `submit-claim(...)` – Submit medical claim with provider, category, and evidence
* `review-claim(claim-id, approve, approval-amount, denial-reason)` – Approve or deny claims

### Provider Management

* `register-provider(...)` – Register as healthcare provider with stake
* `verify-provider(provider)` – Verify healthcare provider (admin only)

### Administration

* `create-health-pool(...)` – Create a new health pool
* `verify-provider(provider)` – Verify and activate provider

### Read-Only Queries

* `get-member-info(member)` – Retrieve member details
* `get-pool-info(pool-id)` – Retrieve pool details
* `get-claim-info(claim-id)` – Retrieve claim details
* `get-provider-info(provider)` – Retrieve provider details
* `check-coverage-status(member)` – Check if member’s coverage is valid
* `calculate-claim-eligibility(member, claim-amount, category)` – Estimate claim eligibility and approval probability
* `get-platform-stats()` – View global platform statistics

## Error Codes

* `ERR-NOT-AUTHORIZED (600)` – Unauthorized action
* `ERR-INVALID-AMOUNT (601)` – Invalid amount
* `ERR-INSUFFICIENT-FUNDS (602)` – Not enough funds
* `ERR-MEMBER-NOT-FOUND (603)` – Member not found
* `ERR-ALREADY-MEMBER (604)` – Already registered
* `ERR-CLAIM-NOT-FOUND (605)` – Claim not found
* `ERR-INVALID-COVERAGE (606)` – Invalid coverage type
* `ERR-CLAIM-DENIED (607)` – Claim denied
* `ERR-WAITING-PERIOD (608)` – Waiting period not over
* `ERR-COVERAGE-LIMIT (609)` – Claim exceeds coverage limit
* `ERR-INVALID-PROVIDER (610)` – Invalid provider
* `ERR-DUPLICATE-CLAIM (611)` – Duplicate claim
* `ERR-POOL-INACTIVE (612)` – Pool is inactive

## Impact Metrics

* Total members
* Total pools created
* Total claims submitted and processed
* Total premiums collected
* Total claims paid
* Platform reserves balance

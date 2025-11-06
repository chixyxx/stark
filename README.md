# StarkShift - Decentralized Microfinance Platform

## Overview

StarkShift is a decentralized microfinance ecosystem that revolutionizes financial inclusion through autonomous impact verification and community-governed lending pools. Built as a Clarity smart contract for the Stacks blockchain, it creates transparent, privacy-preserving lending solutions that automatically adjust based on verified social outcomes and community achievements.

## Features

- **Community-Governed Lending Pools**: Decentralized lending with transparent fund allocation
- **Impact Circle Validators**: Staked validators who verify loan impacts and borrower credentials
- **Reputation-Based Credit System**: Build credit history through successful loan repayments
- **Proportional Returns**: Lenders receive returns proportional to their contribution
- **Borrower Verification**: Impact Circles can verify borrowers to improve their reputation
- **Platform Sustainability**: Small platform fee (default 2%) for maintenance and development

## Smart Contract Architecture

### Core Components

#### 1. Loans
- Borrowers create loan requests with specified amount, interest rate, and duration
- Loans can be funded by multiple lenders
- Automatic status tracking: `pending` → `funded` → `repaid`
- Impact scores tracked for verified outcomes

#### 2. Borrower Profiles
- Track total borrowed and repaid amounts
- Reputation scores (0-100) that improve with successful repayments
- Verification status from Impact Circles
- Active loan count tracking

#### 3. Impact Circles
- Validator nodes that stake tokens to participate
- Verify borrower credentials and loan impacts
- Earn reputation through successful verifications
- Minimum stake requirement: 1 STX

#### 4. Lender Contributions
- Track individual lender contributions to loans
- Enable proportional return distribution
- Claim mechanism for repaid loans

## Contract Functions

### Public Functions

#### For Borrowers

##### `create-loan`
```clarity
(create-loan (amount uint) (interest-rate uint) (duration-blocks uint) (purpose (string-ascii 100)))
```
Creates a new loan request.
- **Parameters:**
  - `amount`: Loan amount in micro-STX
  - `interest-rate`: Interest rate (0-100 representing 0-10%)
  - `duration-blocks`: Loan duration in blocks
  - `purpose`: Description of loan purpose
- **Returns:** Loan ID
- **Requirements:** Valid amount and interest rate

##### `repay-loan`
```clarity
(repay-loan (loan-id uint))
```
Repays a funded loan with interest.
- **Parameters:**
  - `loan-id`: ID of the loan to repay
- **Returns:** Amount transferred to repayment pool
- **Requirements:** Must be borrower, loan must be funded
- **Effect:** Increases reputation score by 10 points

#### For Lenders

##### `fund-loan`
```clarity
(fund-loan (loan-id uint) (fund-amount uint))
```
Contributes funds to a pending loan.
- **Parameters:**
  - `loan-id`: ID of the loan to fund
  - `fund-amount`: Amount to contribute in micro-STX
- **Returns:** Actual amount funded
- **Effect:** When fully funded, transfers funds to borrower

##### `claim-returns`
```clarity
(claim-returns (loan-id uint))
```
Claims principal + interest returns from a repaid loan.
- **Parameters:**
  - `loan-id`: ID of the repaid loan
- **Returns:** Amount claimed
- **Requirements:** Loan must be repaid, contribution not yet claimed

#### For Impact Circle Validators

##### `register-impact-circle`
```clarity
(register-impact-circle (name (string-ascii 50)) (stake-amount uint))
```
Registers as an Impact Circle validator.
- **Parameters:**
  - `name`: Name of the Impact Circle
  - `stake-amount`: Amount to stake (minimum 1 STX)
- **Returns:** Success boolean
- **Requirements:** Minimum 1 STX stake, not already registered

##### `update-impact-score`
```clarity
(update-impact-score (loan-id uint) (new-score uint))
```
Updates the impact score for a loan.
- **Parameters:**
  - `loan-id`: ID of the loan
  - `new-score`: New impact score (0-100)
- **Returns:** Success boolean
- **Requirements:** Must be active Impact Circle validator

##### `verify-borrower`
```clarity
(verify-borrower (borrower principal))
```
Verifies a borrower's credentials.
- **Parameters:**
  - `borrower`: Principal address of borrower to verify
- **Returns:** Success boolean
- **Effect:** Sets verified status and adds 20 reputation points

### Read-Only Functions

##### `get-loan`
```clarity
(get-loan (loan-id uint))
```
Retrieves loan details by ID.

##### `get-borrower-profile`
```clarity
(get-borrower-profile (borrower principal))
```
Retrieves borrower profile information.

##### `get-impact-circle`
```clarity
(get-impact-circle (validator principal))
```
Retrieves Impact Circle validator information.

##### `get-lender-contribution`
```clarity
(get-lender-contribution (loan-id uint) (lender principal))
```
Retrieves specific lender's contribution to a loan.

##### `get-total-loans`
```clarity
(get-total-loans)
```
Returns total number of loans created.

##### `get-total-funded`
```clarity
(get-total-funded)
```
Returns total amount funded across all loans.

##### `calculate-interest`
```clarity
(calculate-interest (amount uint) (rate uint) (duration uint))
```
Calculates interest for given parameters.

## Usage Examples

### Creating a Loan

```clarity
;; Create a loan for 10 STX with 5% interest for 1000 blocks
(contract-call? .starkshift create-loan u10000000 u50 u1000 "Agricultural equipment")
```

### Funding a Loan

```clarity
;; Fund loan #1 with 5 STX
(contract-call? .starkshift fund-loan u1 u5000000)
```

### Registering as Impact Circle

```clarity
;; Register with 1 STX stake
(contract-call? .starkshift register-impact-circle "Community Validators NG" u1000000)
```

### Repaying a Loan

```clarity
;; Repay loan #1
(contract-call? .starkshift repay-loan u1)
```

### Claiming Returns

```clarity
;; Claim returns from loan #1
(contract-call? .starkshift claim-returns u1)
```

## Economic Model

### Interest Calculation
Interest is calculated as:
```
Interest = (Amount × Rate × Duration) / 1,000,000
```

### Platform Fee
- Default: 2% of total repayment (principal + interest)
- Adjustable by contract owner (max 10%)
- Deducted before distribution to lenders

### Returns Distribution
Lenders receive returns proportional to their contribution:
```
Lender Share = (Repayment Pool × Lender Contribution) / Total Loan Amount
```

Where `Repayment Pool = Total Repayment - Platform Fee`

### Reputation System
- Starting score: 50
- Verification bonus: +20 points
- Successful repayment: +10 points
- Maximum score: 100

## Security Features

1. **Authorization Checks**: All sensitive functions verify caller permissions
2. **Status Validation**: Loans can only progress through valid state transitions
3. **Stake Requirements**: Validators must stake minimum amount
4. **Amount Validation**: All amounts validated against constraints
5. **Ownership Controls**: Administrative functions restricted to contract owner

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u100 | err-owner-only | Function restricted to contract owner |
| u101 | err-not-found | Resource not found |
| u102 | err-insufficient-funds | Insufficient funds for operation |
| u103 | err-already-exists | Resource already exists |
| u104 | err-unauthorized | Caller not authorized |
| u105 | err-loan-active | Loan is active (blocking operation) |
| u106 | err-invalid-amount | Invalid amount provided |
| u107 | err-invalid-status | Invalid loan status for operation |

## Deployment

### Prerequisites
- Stacks blockchain node or access to testnet/mainnet
- Clarinet CLI for local testing and deployment
- STX tokens for deployment and staking

### Deployment Steps

1. **Local Testing**
```bash
clarinet console
```

2. **Deploy to Testnet**
```bash
clarinet deploy --testnet
```

3. **Deploy to Mainnet**
```bash
clarinet deploy --mainnet
```

## Future Enhancements

- **Crisis Response Mechanisms**: Automatic emergency funding triggers
- **Cross-Chain Integration**: Bridge to other blockchain networks
- **AI-Powered Risk Assessment**: Automated credit scoring
- **Conditional Impact Tokens**: Token rewards based on verified outcomes
- **Mobile Money Integration**: Direct integration with mobile payment systems
- **Satellite & IoT Verification**: Real-world data integration for impact verification


;; StarkShift - Decentralized Microfinance Smart Contract
;; A community-governed lending platform with impact verification

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-funds (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-unauthorized (err u104))
(define-constant err-loan-active (err u105))
(define-constant err-invalid-amount (err u106))
(define-constant err-invalid-status (err u107))

;; Data Variables
(define-data-var total-loans uint u0)
(define-data-var total-funded uint u0)
(define-data-var platform-fee-percentage uint u2) ;; 2% platform fee

;; Data Maps
(define-map loans
    uint
    {
        borrower: principal,
        amount: uint,
        funded-amount: uint,
        interest-rate: uint,
        duration-blocks: uint,
        created-at: uint,
        funded-at: (optional uint),
        repaid-at: (optional uint),
        status: (string-ascii 20),
        impact-score: uint,
        purpose: (string-ascii 100)
    }
)

(define-map borrower-profiles
    principal
    {
        total-borrowed: uint,
        total-repaid: uint,
        active-loans: uint,
        reputation-score: uint,
        verified: bool
    }
)

(define-map lender-contributions
    { loan-id: uint, lender: principal }
    { amount: uint, claimed: bool }
)

(define-map impact-circles
    principal
    {
        name: (string-ascii 50),
        stake: uint,
        verified-loans: uint,
        active: bool
    }
)

(define-map loan-funders
    { loan-id: uint, funder: principal }
    uint
)

;; Read-only functions
(define-read-only (get-loan (loan-id uint))
    (map-get? loans loan-id)
)

(define-read-only (get-borrower-profile (borrower principal))
    (map-get? borrower-profiles borrower)
)

(define-read-only (get-impact-circle (validator principal))
    (map-get? impact-circles validator)
)

(define-read-only (get-lender-contribution (loan-id uint) (lender principal))
    (map-get? lender-contributions { loan-id: loan-id, lender: lender })
)

(define-read-only (get-total-loans)
    (var-get total-loans)
)

(define-read-only (get-total-funded)
    (var-get total-funded)
)

(define-read-only (get-platform-fee)
    (var-get platform-fee-percentage)
)

(define-read-only (calculate-interest (amount uint) (rate uint) (duration uint))
    (/ (* (* amount rate) duration) u1000000)
)

;; Public functions

;; Register as Impact Circle validator
(define-public (register-impact-circle (name (string-ascii 50)) (stake-amount uint))
    (let
        (
            (existing-circle (map-get? impact-circles tx-sender))
        )
        (asserts! (is-none existing-circle) err-already-exists)
        (asserts! (>= stake-amount u1000000) err-invalid-amount) ;; Minimum 1 STX stake
        
        (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
        
        (ok (map-set impact-circles tx-sender {
            name: name,
            stake: stake-amount,
            verified-loans: u0,
            active: true
        }))
    )
)

;; Create a new loan request
(define-public (create-loan (amount uint) (interest-rate uint) (duration-blocks uint) (purpose (string-ascii 100)))
    (let
        (
            (loan-id (+ (var-get total-loans) u1))
            (borrower-profile (default-to 
                { total-borrowed: u0, total-repaid: u0, active-loans: u0, reputation-score: u50, verified: false }
                (map-get? borrower-profiles tx-sender)
            ))
        )
        (asserts! (> amount u0) err-invalid-amount)
        (asserts! (<= interest-rate u100) err-invalid-amount) ;; Max 10% interest rate
        
        (map-set loans loan-id {
            borrower: tx-sender,
            amount: amount,
            funded-amount: u0,
            interest-rate: interest-rate,
            duration-blocks: duration-blocks,
            created-at: block-height,
            funded-at: none,
            repaid-at: none,
            status: "pending",
            impact-score: u0,
            purpose: purpose
        })
        
        (map-set borrower-profiles tx-sender (merge borrower-profile {
            active-loans: (+ (get active-loans borrower-profile) u1)
        }))
        
        (var-set total-loans loan-id)
        (ok loan-id)
    )
)

;; Fund a loan
(define-public (fund-loan (loan-id uint) (fund-amount uint))
    (let
        (
            (loan (unwrap! (map-get? loans loan-id) err-not-found))
            (remaining (- (get amount loan) (get funded-amount loan)))
            (actual-amount (if (<= fund-amount remaining) fund-amount remaining))
            (new-funded (+ (get funded-amount loan) actual-amount))
        )
        (asserts! (is-eq (get status loan) "pending") err-invalid-status)
        (asserts! (> actual-amount u0) err-invalid-amount)
        
        (try! (stx-transfer? actual-amount tx-sender (as-contract tx-sender)))
        
        (map-set loan-funders { loan-id: loan-id, funder: tx-sender } actual-amount)
        
        (map-set lender-contributions 
            { loan-id: loan-id, lender: tx-sender }
            { amount: actual-amount, claimed: false }
        )
        
        (if (>= new-funded (get amount loan))
            (begin
                (map-set loans loan-id (merge loan {
                    funded-amount: new-funded,
                    status: "funded",
                    funded-at: (some block-height)
                }))
                (try! (as-contract (stx-transfer? (get amount loan) tx-sender (get borrower loan))))
                (var-set total-funded (+ (var-get total-funded) (get amount loan)))
            )
            (map-set loans loan-id (merge loan {
                funded-amount: new-funded
            }))
        )
        
        (ok actual-amount)
    )
)

;; Repay a loan
(define-public (repay-loan (loan-id uint))
    (let
        (
            (loan (unwrap! (map-get? loans loan-id) err-not-found))
            (borrower-profile (unwrap! (map-get? borrower-profiles tx-sender) err-not-found))
            (interest (calculate-interest (get amount loan) (get interest-rate loan) (get duration-blocks loan)))
            (total-repayment (+ (get amount loan) interest))
            (platform-fee (/ (* total-repayment (var-get platform-fee-percentage)) u100))
            (repayment-to-pool (- total-repayment platform-fee))
        )
        (asserts! (is-eq tx-sender (get borrower loan)) err-unauthorized)
        (asserts! (is-eq (get status loan) "funded") err-invalid-status)
        
        (try! (stx-transfer? total-repayment tx-sender (as-contract tx-sender)))
        (try! (as-contract (stx-transfer? platform-fee tx-sender contract-owner)))
        
        (map-set loans loan-id (merge loan {
            status: "repaid",
            repaid-at: (some block-height)
        }))
        
        (map-set borrower-profiles tx-sender (merge borrower-profile {
            total-repaid: (+ (get total-repaid borrower-profile) total-repayment),
            active-loans: (- (get active-loans borrower-profile) u1),
            reputation-score: (if (< (get reputation-score borrower-profile) u100)
                (+ (get reputation-score borrower-profile) u10)
                u100
            )
        }))
        
        (ok repayment-to-pool)
    )
)

;; Claim returns as a lender
(define-public (claim-returns (loan-id uint))
    (let
        (
            (loan (unwrap! (map-get? loans loan-id) err-not-found))
            (contribution (unwrap! (map-get? lender-contributions { loan-id: loan-id, lender: tx-sender }) err-not-found))
            (interest (calculate-interest (get amount loan) (get interest-rate loan) (get duration-blocks loan)))
            (total-repayment (+ (get amount loan) interest))
            (platform-fee (/ (* total-repayment (var-get platform-fee-percentage)) u100))
            (repayment-pool (- total-repayment platform-fee))
            (lender-share (/ (* repayment-pool (get amount contribution)) (get amount loan)))
        )
        (asserts! (is-eq (get status loan) "repaid") err-invalid-status)
        (asserts! (not (get claimed contribution)) err-unauthorized)
        
        (map-set lender-contributions 
            { loan-id: loan-id, lender: tx-sender }
            (merge contribution { claimed: true })
        )
        
        (try! (as-contract (stx-transfer? lender-share tx-sender tx-sender)))
        
        (ok lender-share)
    )
)

;; Update impact score (can only be called by registered Impact Circle)
(define-public (update-impact-score (loan-id uint) (new-score uint))
    (let
        (
            (loan (unwrap! (map-get? loans loan-id) err-not-found))
            (validator (unwrap! (map-get? impact-circles tx-sender) err-unauthorized))
        )
        (asserts! (get active validator) err-unauthorized)
        (asserts! (<= new-score u100) err-invalid-amount)
        
        (map-set loans loan-id (merge loan {
            impact-score: new-score
        }))
        
        (map-set impact-circles tx-sender (merge validator {
            verified-loans: (+ (get verified-loans validator) u1)
        }))
        
        (ok true)
    )
)

;; Verify borrower (can only be called by Impact Circle)
(define-public (verify-borrower (borrower principal))
    (let
        (
            (validator (unwrap! (map-get? impact-circles tx-sender) err-unauthorized))
            (borrower-profile (default-to 
                { total-borrowed: u0, total-repaid: u0, active-loans: u0, reputation-score: u50, verified: false }
                (map-get? borrower-profiles borrower)
            ))
        )
        (asserts! (get active validator) err-unauthorized)
        
        (ok (map-set borrower-profiles borrower (merge borrower-profile {
            verified: true,
            reputation-score: (+ (get reputation-score borrower-profile) u20)
        })))
    )
)

;; Admin function to update platform fee
(define-public (set-platform-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-fee u10) err-invalid-amount) ;; Max 10% fee
        (ok (var-set platform-fee-percentage new-fee))
    )
)

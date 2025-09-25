;;; ===================================================
;;; HEALTHSHARE - COMMUNITY HEALTH INSURANCE POOL
;;; ===================================================
;;; A blockchain-based community health insurance system for
;;; underserved populations with transparent claims processing.
;;; Addresses UN SDG 3: Good Health and Well-Being through accessible healthcare.
;;; ===================================================

;; ===================================================
;; CONSTANTS AND ERROR CODES
;; ===================================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u600))
(define-constant ERR-INVALID-AMOUNT (err u601))
(define-constant ERR-INSUFFICIENT-FUNDS (err u602))
(define-constant ERR-MEMBER-NOT-FOUND (err u603))
(define-constant ERR-ALREADY-MEMBER (err u604))
(define-constant ERR-CLAIM-NOT-FOUND (err u605))
(define-constant ERR-INVALID-COVERAGE (err u606))
(define-constant ERR-CLAIM-DENIED (err u607))
(define-constant ERR-WAITING-PERIOD (err u608))
(define-constant ERR-COVERAGE-LIMIT (err u609))
(define-constant ERR-INVALID-PROVIDER (err u610))
(define-constant ERR-DUPLICATE-CLAIM (err u611))
(define-constant ERR-POOL-INACTIVE (err u612))

;; Coverage Types
(define-constant BASIC-COVERAGE u1)
(define-constant STANDARD-COVERAGE u2)
(define-constant PREMIUM-COVERAGE u3)
(define-constant EMERGENCY-COVERAGE u4)

;; Claim Status
(define-constant CLAIM-SUBMITTED u0)
(define-constant CLAIM-UNDER-REVIEW u1)
(define-constant CLAIM-APPROVED u2)
(define-constant CLAIM-DENIED u3)
(define-constant CLAIM-PAID u4)

;; Medical Categories
(define-constant CATEGORY-GENERAL u1)
(define-constant CATEGORY-EMERGENCY u2)
(define-constant CATEGORY-MATERNAL u3)
(define-constant CATEGORY-CHRONIC u4)
(define-constant CATEGORY-PREVENTIVE u5)
(define-constant CATEGORY-DENTAL u6)
(define-constant CATEGORY-MENTAL u7)

;; Time Constants
(define-constant BLOCKS-PER-MONTH u4320)
(define-constant WAITING-PERIOD-BLOCKS u17280) ;; 4 months
(define-constant CLAIM-REVIEW-PERIOD u1440) ;; 10 days

;; Financial Constants
(define-constant MIN-PREMIUM u500000) ;; 0.5 STX monthly
(define-constant MAX-CLAIM-AMOUNT u500000000) ;; 500 STX
(define-constant ADMIN-FEE-RATE u300) ;; 3%

;; ===================================================
;; DATA STRUCTURES
;; ===================================================

;; Health Pool Members
(define-map health-members
    { member: principal }
    {
        member-name: (string-ascii 100),
        age: uint,
        coverage-type: uint,
        monthly-premium: uint,
        enrollment-date: uint,
        last-premium-paid: uint,
        total-premiums-paid: uint,
        claims-submitted: uint,
        claims-approved: uint,
        total-claims-amount: uint,
        is-active: bool,
        health-score: uint, ;; 0-100
        pre-existing-conditions: (list 5 (string-ascii 50)),
        emergency-contact: (string-ascii 150),
        location: (string-ascii 100)
    }
)

;; Health Insurance Pools
(define-map health-pools
    { pool-id: uint }
    {
        pool-name: (string-ascii 100),
        target-demographic: (string-ascii 100),
        total-members: uint,
        pool-balance: uint,
        total-premiums-collected: uint,
        total-claims-paid: uint,
        coverage-limits: (list 7 uint), ;; limits per category
        monthly-premium-base: uint,
        is-active: bool,
        creation-date: uint,
        pool-manager: principal,
        reserve-ratio: uint ;; percentage kept as reserve
    }
)

;; Medical Claims
(define-map medical-claims
    { claim-id: uint }
    {
        claimant: principal,
        pool-id: uint,
        provider: principal,
        claim-amount: uint,
        medical-category: uint,
        treatment-date: uint,
        claim-date: uint,
        claim-status: uint,
        approval-amount: uint,
        denial-reason: (optional (string-ascii 200)),
        medical-evidence: (buff 64),
        reviewed-by: (optional principal),
        review-date: (optional uint),
        payment-date: (optional uint),
        treatment-description: (string-ascii 300)
    }
)

;; Healthcare Providers
(define-map healthcare-providers
    { provider: principal }
    {
        provider-name: (string-ascii 100),
        license-number: (string-ascii 50),
        specialization: (string-ascii 100),
        location: (string-ascii 100),
        verification-status: bool,
        services-provided: (list 10 (string-ascii 50)),
        claims-processed: uint,
        success-rate: uint, ;; percentage * 100
        registration-date: uint,
        is-active: bool,
        stake-amount: uint
    }
)

;; Premium Payments
(define-map premium-payments
    { payment-id: uint }
    {
        member: principal,
        pool-id: uint,
        payment-amount: uint,
        payment-date: uint,
        coverage-period-start: uint,
        coverage-period-end: uint,
        payment-method: (string-ascii 30),
        late-fee: uint,
        is-recurring: bool
    }
)

;; Health Risk Assessments
(define-map risk-assessments
    { assessment-id: uint }
    {
        member: principal,
        assessor: principal,
        assessment-date: uint,
        health-metrics: (list 10 uint),
        risk-score: uint, ;; 0-100
        recommendations: (string-ascii 500),
        validity-period: uint,
        assessment-type: (string-ascii 50)
    }
)

;; Community Health Fund
(define-map emergency-fund
    { fund-id: uint }
    {
        fund-name: (string-ascii 100),
        target-condition: (string-ascii 100),
        fund-balance: uint,
        contributions-received: uint,
        beneficiaries-helped: uint,
        is-active: bool,
        creation-date: uint,
        emergency-threshold: uint
    }
)

;; ===================================================
;; DATA VARIABLES
;; ===================================================

(define-data-var next-pool-id uint u1)
(define-data-var next-claim-id uint u1)
(define-data-var next-payment-id uint u1)
(define-data-var next-assessment-id uint u1)
(define-data-var next-fund-id uint u1)
(define-data-var total-members uint u0)
(define-data-var platform-reserves uint u0)
(define-data-var total-claims-processed uint u0)

;; ===================================================
;; PRIVATE FUNCTIONS
;; ===================================================

;; Validate coverage type
(define-private (is-valid-coverage-type (coverage-type uint))
    (or (is-eq coverage-type BASIC-COVERAGE)
        (or (is-eq coverage-type STANDARD-COVERAGE)
            (or (is-eq coverage-type PREMIUM-COVERAGE)
                (is-eq coverage-type EMERGENCY-COVERAGE))))
)

;; Calculate premium based on age and health score
(define-private (calculate-premium (base-premium uint) (age uint) (health-score uint) (coverage-type uint))
    (let (
        (age-factor (if (< age u30) u80
                    (if (< age u50) u100
                    (if (< age u65) u120 u150))))
        (health-factor (if (> health-score u80) u80
                      (if (> health-score u60) u100
                      (if (> health-score u40) u120 u140))))
        (coverage-factor (if (is-eq coverage-type BASIC-COVERAGE) u100
                         (if (is-eq coverage-type STANDARD-COVERAGE) u150
                         (if (is-eq coverage-type PREMIUM-COVERAGE) u200 u120))))
    )
        (/ (* (* (* base-premium age-factor) health-factor) coverage-factor) u1000000)
    )
)

;; Check if member is in good standing
(define-private (is-member-in-good-standing (member principal))
    (match (map-get? health-members { member: member })
        member-data
            (and (get is-active member-data)
                 (> (+ (get last-premium-paid member-data) BLOCKS-PER-MONTH)
                    stacks-block-height))
        false
    )
)

;; Validate medical category
(define-private (is-valid-medical-category (category uint))
    (or (is-eq category CATEGORY-GENERAL)
        (or (is-eq category CATEGORY-EMERGENCY)
            (or (is-eq category CATEGORY-MATERNAL)
                (or (is-eq category CATEGORY-CHRONIC)
                    (or (is-eq category CATEGORY-PREVENTIVE)
                        (or (is-eq category CATEGORY-DENTAL)
                            (is-eq category CATEGORY-MENTAL)))))))
)

;; Calculate claim approval probability based on evidence
(define-private (calculate-approval-probability (member principal) (claim-amount uint) (category uint))
    (match (map-get? health-members { member: member })
        member-data
            (let (
                (claim-history-factor (if (> (get claims-submitted member-data) u0)
                                        (/ (* (get claims-approved member-data) u100) (get claims-submitted member-data))
                                        u80))
                (amount-factor (if (< claim-amount u10000000) u90 ;; Small claims more likely
                               (if (< claim-amount u50000000) u70
                                   u50)))
                (category-factor (if (is-eq category CATEGORY-EMERGENCY) u95
                                (if (is-eq category CATEGORY-PREVENTIVE) u90
                                    u80)))
            )
                (/ (+ (+ claim-history-factor amount-factor) category-factor) u3)
            )
        u50
    )
)

;; ===================================================
;; PUBLIC FUNCTIONS - MEMBER MANAGEMENT
;; ===================================================

;; Join health pool
(define-public (join-health-pool
    (pool-id uint)
    (member-name (string-ascii 100))
    (age uint)
    (coverage-type uint)
    (pre-existing-conditions (list 5 (string-ascii 50)))
    (emergency-contact (string-ascii 150))
    (location (string-ascii 100)))
    
    (let (
        (pool-data (unwrap! (map-get? health-pools { pool-id: pool-id }) ERR-INVALID-COVERAGE))
        (base-premium (get monthly-premium-base pool-data))
        (calculated-premium (calculate-premium base-premium age u75 coverage-type))
        (enrollment-date stacks-block-height)
    )
    
    (asserts! (is-none (map-get? health-members { member: tx-sender })) ERR-ALREADY-MEMBER)
    (asserts! (get is-active pool-data) ERR-POOL-INACTIVE)
    (asserts! (is-valid-coverage-type coverage-type) ERR-INVALID-COVERAGE)
    (asserts! (and (>= age u18) (<= age u100)) ERR-INVALID-AMOUNT)
    
    ;; Pay first premium
    (try! (stx-transfer? calculated-premium tx-sender (as-contract tx-sender)))
    
    ;; Register member
    (map-set health-members
        { member: tx-sender }
        {
            member-name: member-name,
            age: age,
            coverage-type: coverage-type,
            monthly-premium: calculated-premium,
            enrollment-date: enrollment-date,
            last-premium-paid: enrollment-date,
            total-premiums-paid: calculated-premium,
            claims-submitted: u0,
            claims-approved: u0,
            total-claims-amount: u0,
            is-active: true,
            health-score: u75,
            pre-existing-conditions: pre-existing-conditions,
            emergency-contact: emergency-contact,
            location: location
        }
    )
    
    ;; Update pool stats
    (map-set health-pools
        { pool-id: pool-id }
        (merge pool-data {
            total-members: (+ (get total-members pool-data) u1),
            pool-balance: (+ (get pool-balance pool-data) calculated-premium),
            total-premiums-collected: (+ (get total-premiums-collected pool-data) calculated-premium)
        })
    )
    
    (var-set total-members (+ (var-get total-members) u1))
    (ok true)
    )
)

;; Pay monthly premium
(define-public (pay-premium (pool-id uint))
    (let (
        (member-data (unwrap! (map-get? health-members { member: tx-sender }) ERR-MEMBER-NOT-FOUND))
        (pool-data (unwrap! (map-get? health-pools { pool-id: pool-id }) ERR-INVALID-COVERAGE))
        (premium-amount (get monthly-premium member-data))
        (payment-id (var-get next-payment-id))
        (coverage-start stacks-block-height)
        (coverage-end (+ coverage-start BLOCKS-PER-MONTH))
    )
    
    (asserts! (get is-active member-data) ERR-MEMBER-NOT-FOUND)
    (asserts! (get is-active pool-data) ERR-POOL-INACTIVE)
    
    ;; Transfer premium
    (try! (stx-transfer? premium-amount tx-sender (as-contract tx-sender)))
    
    ;; Record payment
    (map-set premium-payments
        { payment-id: payment-id }
        {
            member: tx-sender,
            pool-id: pool-id,
            payment-amount: premium-amount,
            payment-date: stacks-block-height,
            coverage-period-start: coverage-start,
            coverage-period-end: coverage-end,
            payment-method: "STX_TRANSFER",
            late-fee: u0,
            is-recurring: false
        }
    )
    
    ;; Update member record
    (map-set health-members
        { member: tx-sender }
        (merge member-data {
            last-premium-paid: stacks-block-height,
            total-premiums-paid: (+ (get total-premiums-paid member-data) premium-amount)
        })
    )
    
    ;; Update pool balance
    (map-set health-pools
        { pool-id: pool-id }
        (merge pool-data {
            pool-balance: (+ (get pool-balance pool-data) premium-amount),
            total-premiums-collected: (+ (get total-premiums-collected pool-data) premium-amount)
        })
    )
    
    (var-set next-payment-id (+ payment-id u1))
    (ok coverage-end)
    )
)

;; ===================================================
;; PUBLIC FUNCTIONS - CLAIMS PROCESSING
;; ===================================================

;; Submit medical claim
(define-public (submit-claim
    (pool-id uint)
    (provider principal)
    (claim-amount uint)
    (medical-category uint)
    (treatment-date uint)
    (treatment-description (string-ascii 300))
    (medical-evidence (buff 64)))
    
    (let (
        (claim-id (var-get next-claim-id))
        (member-data (unwrap! (map-get? health-members { member: tx-sender }) ERR-MEMBER-NOT-FOUND))
        (pool-data (unwrap! (map-get? health-pools { pool-id: pool-id }) ERR-INVALID-COVERAGE))
        (provider-data (unwrap! (map-get? healthcare-providers { provider: provider }) ERR-INVALID-PROVIDER))
        (waiting-period-end (+ (get enrollment-date member-data) WAITING-PERIOD-BLOCKS))
    )
    
    (asserts! (is-member-in-good-standing tx-sender) ERR-MEMBER-NOT-FOUND)
    (asserts! (get verification-status provider-data) ERR-INVALID-PROVIDER)
    (asserts! (is-valid-medical-category medical-category) ERR-INVALID-COVERAGE)
    (asserts! (> claim-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= claim-amount MAX-CLAIM-AMOUNT) ERR-COVERAGE-LIMIT)
    
    ;; Check waiting period (except for emergencies)
    (if (not (is-eq medical-category CATEGORY-EMERGENCY))
        (asserts! (> stacks-block-height waiting-period-end) ERR-WAITING-PERIOD)
        true
    )
    
    ;; Submit claim
    (map-set medical-claims
        { claim-id: claim-id }
        {
            claimant: tx-sender,
            pool-id: pool-id,
            provider: provider,
            claim-amount: claim-amount,
            medical-category: medical-category,
            treatment-date: treatment-date,
            claim-date: stacks-block-height,
            claim-status: CLAIM-SUBMITTED,
            approval-amount: u0,
            denial-reason: none,
            medical-evidence: medical-evidence,
            reviewed-by: none,
            review-date: none,
            payment-date: none,
            treatment-description: treatment-description
        }
    )
    
    ;; Update member stats
    (map-set health-members
        { member: tx-sender }
        (merge member-data {
            claims-submitted: (+ (get claims-submitted member-data) u1)
        })
    )
    
    (var-set next-claim-id (+ claim-id u1))
    (ok claim-id)
    )
)

;; Review and process claim
(define-public (review-claim (claim-id uint) (approve bool) (approval-amount uint) (denial-reason (optional (string-ascii 200))))
    (let (
        (claim-data (unwrap! (map-get? medical-claims { claim-id: claim-id }) ERR-CLAIM-NOT-FOUND))
        (member-data (unwrap! (map-get? health-members { member: (get claimant claim-data) }) ERR-MEMBER-NOT-FOUND))
        (pool-data (unwrap! (map-get? health-pools { pool-id: (get pool-id claim-data) }) ERR-INVALID-COVERAGE))
        (provider-data (unwrap! (map-get? healthcare-providers { provider: (get provider claim-data) }) ERR-INVALID-PROVIDER))
    )
    
    ;; Only pool manager or contract owner can review
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER)
                  (is-eq tx-sender (get pool-manager pool-data))
                  (get verification-status provider-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get claim-status claim-data) CLAIM-SUBMITTED) ERR-CLAIM-NOT-FOUND)
    
    (if approve
        (begin
            ;; Approve claim
            (asserts! (<= approval-amount (get claim-amount claim-data)) ERR-INVALID-AMOUNT)
            (asserts! (<= approval-amount (get pool-balance pool-data)) ERR-INSUFFICIENT-FUNDS)
            
            ;; Transfer approved amount to claimant
            (try! (as-contract (stx-transfer? approval-amount tx-sender (get claimant claim-data))))
            
            ;; Update claim
            (map-set medical-claims
                { claim-id: claim-id }
                (merge claim-data {
                    claim-status: CLAIM-APPROVED,
                    approval-amount: approval-amount,
                    reviewed-by: (some tx-sender),
                    review-date: (some stacks-block-height),
                    payment-date: (some stacks-block-height)
                })
            )
            
            ;; Update member stats
            (map-set health-members
                { member: (get claimant claim-data) }
                (merge member-data {
                    claims-approved: (+ (get claims-approved member-data) u1),
                    total-claims-amount: (+ (get total-claims-amount member-data) approval-amount)
                })
            )
            
            ;; Update pool balance
            (map-set health-pools
                { pool-id: (get pool-id claim-data) }
                (merge pool-data {
                    pool-balance: (- (get pool-balance pool-data) approval-amount),
                    total-claims-paid: (+ (get total-claims-paid pool-data) approval-amount)
                })
            )
            
            (var-set total-claims-processed (+ (var-get total-claims-processed) u1))
        )
        (begin
            ;; Deny claim
            (map-set medical-claims
                { claim-id: claim-id }
                (merge claim-data {
                    claim-status: CLAIM-DENIED,
                    denial-reason: denial-reason,
                    reviewed-by: (some tx-sender),
                    review-date: (some stacks-block-height)
                })
            )
        )
    )
    
    (ok approve)
    )
)

;; ===================================================
;; PUBLIC FUNCTIONS - PROVIDER MANAGEMENT
;; ===================================================

;; Register as healthcare provider
(define-public (register-provider
    (provider-name (string-ascii 100))
    (license-number (string-ascii 50))
    (specialization (string-ascii 100))
    (location (string-ascii 100))
    (services-provided (list 10 (string-ascii 50)))
    (stake-amount uint))
    
    (begin
    (asserts! (is-none (map-get? healthcare-providers { provider: tx-sender })) ERR-ALREADY-MEMBER)
    (asserts! (>= stake-amount u10000000) ERR-INVALID-AMOUNT) ;; 10 STX minimum stake
    
    ;; Transfer stake
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    
    ;; Register provider
    (map-set healthcare-providers
        { provider: tx-sender }
        {
            provider-name: provider-name,
            license-number: license-number,
            specialization: specialization,
            location: location,
            verification-status: false, ;; Requires manual verification
            services-provided: services-provided,
            claims-processed: u0,
            success-rate: u0,
            registration-date: stacks-block-height,
            is-active: true,
            stake-amount: stake-amount
        }
    )
    
    (ok true)
    )
)

;; ===================================================
;; READ-ONLY FUNCTIONS
;; ===================================================

;; Get member information
(define-read-only (get-member-info (member principal))
    (map-get? health-members { member: member })
)

;; Get pool information
(define-read-only (get-pool-info (pool-id uint))
    (map-get? health-pools { pool-id: pool-id })
)

;; Get claim information
(define-read-only (get-claim-info (claim-id uint))
    (map-get? medical-claims { claim-id: claim-id })
)

;; Get provider information
(define-read-only (get-provider-info (provider principal))
    (map-get? healthcare-providers { provider: provider })
)

;; Check member coverage status
(define-read-only (check-coverage-status (member principal))
    (match (map-get? health-members { member: member })
        member-data
            {
                is-covered: (is-member-in-good-standing member),
                coverage-expires: (+ (get last-premium-paid member-data) BLOCKS-PER-MONTH),
                next-premium-due: (+ (get last-premium-paid member-data) BLOCKS-PER-MONTH),
                premium-amount: (get monthly-premium member-data)
            }
        {
            is-covered: false,
            coverage-expires: u0,
            next-premium-due: u0,
            premium-amount: u0
        }
    )
)

;; Calculate claim eligibility
(define-read-only (calculate-claim-eligibility (member principal) (claim-amount uint) (medical-category uint))
    (match (map-get? health-members { member: member })
        member-data
            (let (
                (approval-probability (calculate-approval-probability member claim-amount medical-category))
                (waiting-period-over (> stacks-block-height (+ (get enrollment-date member-data) WAITING-PERIOD-BLOCKS)))
                (in-good-standing (is-member-in-good-standing member))
            )
                {
                    eligible: (and in-good-standing (or waiting-period-over (is-eq medical-category CATEGORY-EMERGENCY))),
                    approval-probability: approval-probability,
                    waiting-period-over: waiting-period-over,
                    max-claimable: MAX-CLAIM-AMOUNT
                }
            )
        {
            eligible: false,
            approval-probability: u0,
            waiting-period-over: false,
            max-claimable: u0
        }
    )
)

;; Get platform statistics
(define-read-only (get-platform-stats)
    {
        total-members: (var-get total-members),
        total-pools: (var-get next-pool-id),
        total-claims: (var-get next-claim-id),
        claims-processed: (var-get total-claims-processed),
        platform-reserves: (var-get platform-reserves)
    }
)

;; ===================================================
;; ADMIN FUNCTIONS
;; ===================================================

;; Create health insurance pool
(define-public (create-health-pool
    (pool-name (string-ascii 100))
    (target-demographic (string-ascii 100))
    (coverage-limits (list 7 uint))
    (monthly-premium-base uint)
    (reserve-ratio uint))
    
    (let (
        (pool-id (var-get next-pool-id))
    )
    
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> monthly-premium-base MIN-PREMIUM) ERR-INVALID-AMOUNT)
    (asserts! (<= reserve-ratio u50) ERR-INVALID-AMOUNT) ;; Max 50% reserve
    
    (map-set health-pools
        { pool-id: pool-id }
        {
            pool-name: pool-name,
            target-demographic: target-demographic,
            total-members: u0,
            pool-balance: u0,
            total-premiums-collected: u0,
            total-claims-paid: u0,
            coverage-limits: coverage-limits,
            monthly-premium-base: monthly-premium-base,
            is-active: true,
            creation-date: stacks-block-height,
            pool-manager: tx-sender,
            reserve-ratio: reserve-ratio
        }
    )
    
    (var-set next-pool-id (+ pool-id u1))
    (ok pool-id)
    )
)

;; Verify healthcare provider
(define-public (verify-provider (provider principal))
    (let (
        (provider-data (unwrap! (map-get? healthcare-providers { provider: provider }) ERR-INVALID-PROVIDER))
    )
    
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    (map-set healthcare-providers
        { provider: provider }
        (merge provider-data { verification-status: true })
    )
    
    (ok true)
    )
)
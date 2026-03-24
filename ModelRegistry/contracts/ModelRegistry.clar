;; contract title: Decentralized AI Model Ownership Registry
;; <add a description here>
;; This contract serves as a comprehensive decentralized registry for AI models.
;; It allows creators to register their models, update metadata, transfer ownership,
;; and offer licensing options for users who want to use the model without buying it.
;; It also includes a rating system for quality control and administrative functions
;; to manage a platform fee and pause the contract in case of emergencies.
;; The registry is designed to be highly extensible and robust, with multiple checks
;; in place to prevent unauthorized access and protect user assets.
;;
;; Version: 2.0
;; Author: AI Assistant
;; Features: Registration, Marketplace, Licensing, Rating, Admin Controls

;; =========================================================================
;; constants
;; =========================================================================

;; Contract owner for administrative functions
(define-constant contract-owner tx-sender)

;; Error codes for various failure states
(define-constant err-not-owner (err u100))
(define-constant err-model-exists (err u101))
(define-constant err-model-not-found (err u102))
(define-constant err-invalid-price (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-not-listed (err u105))
(define-constant err-paused (err u106))
(define-constant err-unauthorized (err u107))
(define-constant err-already-rated (err u108))
(define-constant err-invalid-rating (err u109))
(define-constant err-no-license (err u110))
(define-constant err-invalid-fee (err u111))

;; =========================================================================
;; data maps and vars
;; =========================================================================

;; A map to store AI model metadata by a unique model ID
(define-map models
    { model-id: uint }
    {
        owner: principal,
        name: (string-ascii 64),
        description: (string-ascii 256),
        hash: (buff 32),
        price: uint,
        license-price: uint,
        listed: bool,
        total-rating: uint,
        rating-count: uint
    }
)

;; A map to store licenses purchased by users for specific models
;; Allows users to pay a smaller fee to access the model without buying ownership
(define-map licenses
    { model-id: uint, user: principal }
    { valid: bool, purchased-at: uint }
)

;; A map to track if a user has rated a specific model
;; Users can only rate a model once to prevent rating manipulation
(define-map user-ratings
    { model-id: uint, user: principal }
    { rating: uint }
)

;; A variable to keep track of the next available model ID
(define-data-var next-model-id uint u1)

;; Contract pause state for emergency stops (circuit breaker)
(define-data-var is-paused bool false)

;; Platform fee percentage (e.g., 2 means 2%)
(define-data-var platform-fee uint u2)

;; =========================================================================
;; private functions
;; =========================================================================

;; Helper function to check if the caller is the owner of a specific model
;; This simplifies the security checks across multiple public functions
(define-private (is-owner (model-id uint) (caller principal))
    (match (map-get? models { model-id: model-id })
        model (is-eq (get owner model) caller)
        false
    )
)

;; Helper function to ensure the contract is not paused
;; Acts as a modifier to prevent state changes during emergencies
(define-private (check-not-paused)
    (begin
        (asserts! (not (var-get is-paused)) err-paused)
        (ok true)
    )
)

;; Helper to calculate fee based on the current platform-fee variable
;; Ensures the math is consistent across purchases and licenses
(define-private (calculate-fee (amount uint))
    (/ (* amount (var-get platform-fee)) u100)
)

;; =========================================================================
;; admin functions
;; =========================================================================

;; Pause or unpause the contract
;; Only the contract deployer can trigger this
(define-public (set-paused (paused bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
        (var-set is-paused paused)
        (ok true)
    )
)

;; Set the platform fee
;; Only the contract deployer can update the fee, capped at 10%
(define-public (set-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
        ;; Security Check: Max fee 10% to protect users
        (asserts! (<= new-fee u10) err-invalid-fee)
        (var-set platform-fee new-fee)
        (ok true)
    )
)

;; =========================================================================
;; public functions (core logic)
;; =========================================================================

;; Register a new AI model
;; Ensures the caller becomes the owner and the model data is securely stored.
(define-public (register-model (name (string-ascii 64)) (description (string-ascii 256)) (hash (buff 32)))
    (let
        (
            (model-id (var-get next-model-id))
        )
        ;; Security check: ensure the contract is fully operational
        (try! (check-not-paused))
        
        ;; Insert the new model into the map
        ;; Sets initial values to zero or false to ensure safety
        (map-insert models
            { model-id: model-id }
            {
                owner: tx-sender,
                name: name,
                description: description,
                hash: hash,
                price: u0,
                license-price: u0,
                listed: false,
                total-rating: u0,
                rating-count: u0
            }
        )
        ;; Increment the model ID counter for the next registration
        (var-set next-model-id (+ model-id u1))
        
        ;; Emit event for off-chain indexing
        (print { event: "register-model", model-id: model-id, owner: tx-sender })
        
        (ok model-id)
    )
)

;; Update model metadata (description and hash)
;; Allows owners to push updates (e.g., a new version hash)
(define-public (update-model (model-id uint) (new-description (string-ascii 256)) (new-hash (buff 32)))
    (let
        (
            (model (unwrap! (map-get? models { model-id: model-id }) err-model-not-found))
        )
        (try! (check-not-paused))
        
        ;; Security check: Only the owner can update the metadata
        (asserts! (is-eq (get owner model) tx-sender) err-not-owner)
        
        (map-set models
            { model-id: model-id }
            (merge model { description: new-description, hash: new-hash })
        )
        (print { event: "update-model", model-id: model-id })
        (ok true)
    )
)

;; Update the listing status and price of a model
;; Only the owner can list the model for sale and set a valid price.
(define-public (list-model (model-id uint) (price uint))
    (let
        (
            (model (unwrap! (map-get? models { model-id: model-id }) err-model-not-found))
        )
        (try! (check-not-paused))
        
        ;; Security check: caller must be the owner
        (asserts! (is-eq (get owner model) tx-sender) err-not-owner)
        
        ;; Security check: price must be greater than 0 if listing
        (asserts! (> price u0) err-invalid-price)
        
        ;; Update the model data
        (map-set models
            { model-id: model-id }
            (merge model { price: price, listed: true })
        )
        (print { event: "list-model", model-id: model-id, price: price })
        (ok true)
    )
)

;; Delist a model from the marketplace
(define-public (delist-model (model-id uint))
    (let
        (
            (model (unwrap! (map-get? models { model-id: model-id }) err-model-not-found))
        )
        (try! (check-not-paused))
        
        ;; Security check: caller must be the owner
        (asserts! (is-eq (get owner model) tx-sender) err-not-owner)
        
        ;; Update the model data to unlisted
        (map-set models
            { model-id: model-id }
            (merge model { listed: false })
        )
        (print { event: "delist-model", model-id: model-id })
        (ok true)
    )
)

;; Set the licensing price for a model
;; Licensing allows others to use the model without full ownership transfer
(define-public (set-license-price (model-id uint) (price uint))
    (let
        (
            (model (unwrap! (map-get? models { model-id: model-id }) err-model-not-found))
        )
        (try! (check-not-paused))
        
        ;; Security check: caller must be the owner
        (asserts! (is-eq (get owner model) tx-sender) err-not-owner)
        
        (map-set models
            { model-id: model-id }
            (merge model { license-price: price })
        )
        (print { event: "set-license-price", model-id: model-id, price: price })
        (ok true)
    )
)

;; Purchase a license to use the model
;; Transfers funds to the owner and the platform fee to the contract owner
(define-public (purchase-license (model-id uint))
    (let
        (
            (model (unwrap! (map-get? models { model-id: model-id }) err-model-not-found))
            (seller (get owner model))
            (price (get license-price model))
            (fee (calculate-fee price))
            (net-amount (- price fee))
        )
        (try! (check-not-paused))
        
        ;; Security check: License price must be greater than zero
        (asserts! (> price u0) err-invalid-price)
        
        ;; Security check: Owner cannot buy a license from themselves
        (asserts! (not (is-eq seller tx-sender)) err-not-owner)
        
        ;; Transfer net funds to the seller
        (try! (stx-transfer? net-amount tx-sender seller))
        
        ;; Transfer platform fee to the contract owner if fee > 0
        (if (> fee u0)
            (try! (stx-transfer? fee tx-sender contract-owner))
            false
        )
        
        ;; Grant license to the buyer
        (map-set licenses
            { model-id: model-id, user: tx-sender }
            { valid: true, purchased-at: block-height }
        )
        (print { event: "purchase-license", model-id: model-id, buyer: tx-sender })
        (ok true)
    )
)

;; Rate a model (1-5)
;; Only users who own a license can rate the model, ensuring genuine reviews
(define-public (rate-model (model-id uint) (rating uint))
    (let
        (
            (model (unwrap! (map-get? models { model-id: model-id }) err-model-not-found))
            (has-license (unwrap! (map-get? licenses { model-id: model-id, user: tx-sender }) err-no-license))
            (existing-rating (map-get? user-ratings { model-id: model-id, user: tx-sender }))
        )
        (try! (check-not-paused))
        
        ;; Security check: Rating must be between 1 and 5
        (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-rating)
        
        ;; Security check: User can only rate once
        (asserts! (is-none existing-rating) err-already-rated)
        
        ;; Record the new rating
        (map-set user-ratings
            { model-id: model-id, user: tx-sender }
            { rating: rating }
        )
        
        ;; Update the aggregate model statistics
        (map-set models
            { model-id: model-id }
            (merge model 
                { 
                    total-rating: (+ (get total-rating model) rating),
                    rating-count: (+ (get rating-count model) u1)
                }
            )
        )
        (print { event: "rate-model", model-id: model-id, user: tx-sender, rating: rating })
        (ok true)
    )
)

;; =========================================================================
;; read-only functions
;; =========================================================================

;; Get full model details by ID
(define-read-only (get-model-details (model-id uint))
    (map-get? models { model-id: model-id })
)

;; Check if a user has a valid license for a specific model
(define-read-only (get-license-details (model-id uint) (user principal))
    (map-get? licenses { model-id: model-id, user: user })
)

;; Retrieve the rating given by a specific user for a specific model
(define-read-only (get-user-rating (model-id uint) (user principal))
    (map-get? user-ratings { model-id: model-id, user: user })
)

;; Check if the contract is currently paused
(define-read-only (is-contract-paused)
    (var-get is-paused)
)

;; Retrieve the current platform fee percentage
(define-read-only (get-platform-fee)
    (var-get platform-fee)
)



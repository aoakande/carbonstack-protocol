;; CarbonStack Protocol - Core Smart Contracts

;; Define NFT Trait
(define-trait carbon-credit-trait
    (
        ;; Transfer token to a specified principal
        (transfer (uint principal principal) (response bool uint))
        
        ;; Get the owner of a specific token ID
        (get-owner (uint) (response principal uint))
        
        ;; Get the last token ID
        (get-last-token-id () (response uint uint))
        
        ;; Get token URI
        (get-token-uri (uint) (response (optional (string-utf8 256)) uint))
    )
)

;; Constants and Configurations
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_PARAMS (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_ALREADY_EXISTS (err u103))

;; Data Structures
(define-map devices 
    { device-id: (string-ascii 64) }
    {
        owner: principal,
        location: (string-ascii 64),
        certification: (string-ascii 128),
        status: bool,
        registration-height: uint,
        last-reading: uint
    }
)

(define-map carbon-credits
    { credit-id: uint }
    {
        owner: principal,
        amount: uint,
        device-id: (string-ascii 64),
        verification-status: bool,
        issuance-height: uint,
        offset-type: (string-ascii 32),
        metadata: (string-ascii 256),
        uri: (optional (string-utf8 256))
    }
)

(define-map verifiers
    { address: principal }
    {
        status: bool,
        verification-count: uint,
        reputation-score: uint,
        last-active: uint
    }
)

;; State Variables
(define-data-var credit-counter uint u0)
(define-data-var protocol-paused bool false)
(define-data-var minimum-stake uint u1000000) ;; in microSTX

;; Authorization Functions
(define-private (is-contract-owner)
    (is-eq tx-sender CONTRACT_OWNER)
)

(define-private (is-verified-device (device-id (string-ascii 64)))
    (match (map-get? devices {device-id: device-id})
        device (get status device)
        false
    )
)

;; Device Management
(define-public (register-device 
    (device-id (string-ascii 64))
    (location (string-ascii 64))
    (certification (string-ascii 128))
)
    (let
        (
            (caller tx-sender)
            (existing-device (map-get? devices {device-id: device-id}))
        )
        (asserts! (is-none existing-device) ERR_ALREADY_EXISTS)
        (map-insert devices
            {device-id: device-id}
            {
                owner: caller,
                location: location,
                certification: certification,
                status: false,
                registration-height: block-height,
                last-reading: u0
            }
        )
        (ok true)
    )
)

;; Carbon Credit Management
(define-public (record-measurement
    (device-id (string-ascii 64))
    (amount uint)
    (offset-type (string-ascii 32))
    (metadata (string-ascii 256))
    (uri (optional (string-utf8 256)))
)
    (let
        (
            (caller tx-sender)
            (new-id (+ (var-get credit-counter) u1))
        )
        (asserts! (is-verified-device device-id) ERR_UNAUTHORIZED)
        (asserts! (> amount u0) ERR_INVALID_PARAMS)
        
        ;; Create new carbon credit
        (map-insert carbon-credits
            {credit-id: new-id}
            {
                owner: caller,
                amount: amount,
                device-id: device-id,
                verification-status: false,
                issuance-height: block-height,
                offset-type: offset-type,
                metadata: metadata,
                uri: uri
            }
        )
        
        ;; Update device last reading
        (map-set devices
            {device-id: device-id}
            (merge (unwrap-panic (map-get? devices {device-id: device-id}))
                {last-reading: block-height}
            )
        )
        
        (var-set credit-counter new-id)
        (ok new-id)
    )
)

;; NFT Trait Implementation
(define-public (transfer (credit-id uint) (sender principal) (recipient principal))
    (let
        (
            (credit (unwrap! (map-get? carbon-credits {credit-id: credit-id}) ERR_NOT_FOUND))
        )
        (asserts! (is-eq (get owner credit) sender) ERR_UNAUTHORIZED)
        (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
        (map-set carbon-credits
            {credit-id: credit-id}
            (merge credit {owner: recipient})
        )
        (ok true)
    )
)

(define-read-only (get-owner (credit-id uint))
    (match (map-get? carbon-credits {credit-id: credit-id})
        credit (ok (get owner credit))
        ERR_NOT_FOUND
    )
)

(define-read-only (get-last-token-id)
    (ok (var-get credit-counter))
)

(define-read-only (get-token-uri (credit-id uint))
    (match (map-get? carbon-credits {credit-id: credit-id})
        credit (ok (get uri credit))
        ERR_NOT_FOUND
    )
)

;; Verification System
(define-public (verify-credit
    (credit-id uint)
)
    (let
        (
            (caller tx-sender)
            (verifier-info (unwrap! (map-get? verifiers {address: caller}) ERR_UNAUTHORIZED))
            (credit (unwrap! (map-get? carbon-credits {credit-id: credit-id}) ERR_NOT_FOUND))
        )
        (asserts! (get status verifier-info) ERR_UNAUTHORIZED)
        
        ;; Update credit verification status
        (map-set carbon-credits
            {credit-id: credit-id}
            (merge credit {verification-status: true})
        )
        
        ;; Update verifier stats
        (map-set verifiers
            {address: caller}
            (merge verifier-info 
                {
                    verification-count: (+ (get verification-count verifier-info) u1),
                    last-active: block-height
                }
            )
        )
        (ok true)
    )
)

;; Emergency Functions
(define-public (pause-protocol)
    (begin
        (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
        (var-set protocol-paused true)
        (ok true)
    )
)

(define-public (resume-protocol)
    (begin
        (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
        (var-set protocol-paused false)
        (ok true)
    )
)

;; Getter Functions
(define-read-only (get-credit-info (credit-id uint))
    (map-get? carbon-credits {credit-id: credit-id})
)

(define-read-only (get-device-info (device-id (string-ascii 64)))
    (map-get? devices {device-id: device-id})
)

(define-read-only (get-verifier-info (address principal))
    (map-get? verifiers {address: address})
)

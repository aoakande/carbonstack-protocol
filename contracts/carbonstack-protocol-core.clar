;; Carbon Credit Verification System Core Contracts

;; Define the data structure for carbon credits
(define-map carbon-credits
    { credit-id: uint }
    {
        owner: principal,
        amount: uint,
        verification-status: bool,
        timestamp: uint,
        location: (string-ascii 64),
        offset-type: (string-ascii 32),
        iot-device-id: (string-ascii 64)
    }
)

;; Define the IoT device registry
(define-map iot-devices
    { device-id: (string-ascii 64) }
    {
        status: bool,
        last-reading: uint,
        location: (string-ascii 64),
        owner: principal
    }
)

;; Initialize credit counter
(define-data-var credit-counter uint u0)

;; Function to register IoT device
(define-public (register-iot-device (device-id (string-ascii 64)) (location (string-ascii 64)))
    (let
        (
            (caller tx-sender)
        )
        (map-insert iot-devices
            { device-id: device-id }
            {
                status: true,
                last-reading: u0,
                location: location,
                owner: caller
            }
        )
        (ok true)
    )
)

;; Function to record carbon offset
(define-public (record-offset 
    (amount uint)
    (device-id (string-ascii 64))
    (offset-type (string-ascii 32))
)
    (let
        (
            (caller tx-sender)
            (new-id (+ (var-get credit-counter) u1))
        )
        (map-insert carbon-credits
            { credit-id: new-id }
            {
                owner: caller,
                amount: amount,
                verification-status: false,
                timestamp: block-height,
                location: (unwrap-panic (get location (map-get? iot-devices { device-id: device-id }))),
                offset-type: offset-type,
                iot-device-id: device-id
            }
        )
        (var-set credit-counter new-id)
        (ok new-id)
    )
)

;; Function to verify carbon credit
(define-public (verify-credit (credit-id uint))
    (let
        (
            (caller tx-sender)
            (credit (unwrap-panic (map-get? carbon-credits { credit-id: credit-id })))
        )
        ;; Add verifier authorization logic here
        (map-set carbon-credits
            { credit-id: credit-id }
            (merge credit { verification-status: true })
        )
        (ok true)
    )
)

;; Function to transfer credits
(define-public (transfer-credit (credit-id uint) (recipient principal))
    (let
        (
            (caller tx-sender)
            (credit (unwrap-panic (map-get? carbon-credits { credit-id: credit-id })))
        )
        (asserts! (is-eq (get owner credit) caller) (err u1))
        (map-set carbon-credits
            { credit-id: credit-id }
            (merge credit { owner: recipient })
        )
        (ok true)
    )
)

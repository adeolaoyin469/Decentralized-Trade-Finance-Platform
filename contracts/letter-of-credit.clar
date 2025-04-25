;; Letter of Credit Contract
;; This contract manages conditional payment guarantees between importers and exporters

(define-data-var admin principal tx-sender)

;; Status enum for letter of credit
(define-constant STATUS-CREATED u1)
(define-constant STATUS-FUNDED u2)
(define-constant STATUS-SHIPPED u3)
(define-constant STATUS-COMPLETED u4)
(define-constant STATUS-CANCELED u5)

;; Map to store letters of credit
(define-map letters-of-credit uint
  {
    exporter: principal,
    importer: principal,
    amount: uint,
    description: (string-utf8 200),
    expiry-height: uint,
    status: uint,
    creation-height: uint
  }
)

;; Map to store funds for letters of credit
(define-map loc-funds uint uint)

;; Counter for letter of credit IDs
(define-data-var loc-id-counter uint u0)

;; Public function to create a letter of credit
(define-public (create-letter-of-credit
    (exporter principal)
    (amount uint)
    (description (string-utf8 200))
    (expiry-blocks uint))
  (let
    (
      (new-id (+ (var-get loc-id-counter) u1))
      (expiry-height (+ block-height expiry-blocks))
    )
    (asserts! (> amount u0) (err u1)) ;; Amount must be positive
    (asserts! (> expiry-blocks u0) (err u2)) ;; Expiry must be in the future

    ;; Set the new letter of credit
    (map-set letters-of-credit new-id {
      exporter: exporter,
      importer: tx-sender,
      amount: amount,
      description: description,
      expiry-height: expiry-height,
      status: STATUS-CREATED,
      creation-height: block-height
    })

    ;; Increment the counter
    (var-set loc-id-counter new-id)
    (ok new-id)
  )
)

;; Public function to fund a letter of credit
(define-public (fund-letter-of-credit (loc-id uint) (amount uint))
  (let
    ((loc (unwrap! (map-get? letters-of-credit loc-id) (err u3))))

    (asserts! (is-eq tx-sender (get importer loc)) (err u4)) ;; Only importer can fund
    (asserts! (is-eq (get status loc) STATUS-CREATED) (err u5)) ;; Must be in CREATED status
    (asserts! (is-eq amount (get amount loc)) (err u6)) ;; Amount must match
    (asserts! (< block-height (get expiry-height loc)) (err u7)) ;; Must not be expired

    ;; Store the funds
    (map-set loc-funds loc-id amount)

    ;; Update status to FUNDED
    (map-set letters-of-credit loc-id
      (merge loc { status: STATUS-FUNDED }))

    (ok true)
  )
)

;; Public function to mark a letter of credit as shipped
(define-public (mark-as-shipped (loc-id uint))
  (let
    ((loc (unwrap! (map-get? letters-of-credit loc-id) (err u3))))

    (asserts! (is-eq tx-sender (get exporter loc)) (err u8)) ;; Only exporter can mark as shipped
    (asserts! (is-eq (get status loc) STATUS-FUNDED) (err u9)) ;; Must be in FUNDED status
    (asserts! (< block-height (get expiry-height loc)) (err u7)) ;; Must not be expired

    ;; Update status to SHIPPED
    (map-set letters-of-credit loc-id
      (merge loc { status: STATUS-SHIPPED }))

    (ok true)
  )
)

;; Public function to complete a letter of credit and release funds
(define-public (complete-letter-of-credit (loc-id uint))
  (let
    ((loc (unwrap! (map-get? letters-of-credit loc-id) (err u3)))
     (funds (unwrap! (map-get? loc-funds loc-id) (err u11))))

    (asserts! (is-eq tx-sender (get importer loc)) (err u4)) ;; Only importer can complete
    (asserts! (is-eq (get status loc) STATUS-SHIPPED) (err u10)) ;; Must be in SHIPPED status
    (asserts! (< block-height (get expiry-height loc)) (err u7)) ;; Must not be expired

    ;; Clear the funds (in a real implementation, this would transfer to the exporter)
    (map-delete loc-funds loc-id)

    ;; Update status to COMPLETED
    (map-set letters-of-credit loc-id
      (merge loc { status: STATUS-COMPLETED }))

    (ok true)
  )
)

;; Public function to cancel an expired letter of credit
(define-public (cancel-expired-letter-of-credit (loc-id uint))
  (let
    ((loc (unwrap! (map-get? letters-of-credit loc-id) (err u3)))
     (funds (unwrap! (map-get? loc-funds loc-id) (err u11))))

    (asserts! (or (is-eq tx-sender (get importer loc)) (is-eq tx-sender (var-get admin))) (err u12))
    (asserts! (>= block-height (get expiry-height loc)) (err u13)) ;; Must be expired
    (asserts! (is-eq (get status loc) STATUS-FUNDED) (err u14)) ;; Only funded LOCs can be canceled

    ;; Clear the funds (in a real implementation, this would return to the importer)
    (map-delete loc-funds loc-id)

    ;; Update status to CANCELED
    (map-set letters-of-credit loc-id
      (merge loc { status: STATUS-CANCELED }))

    (ok true)
  )
)

;; Read-only function to get letter of credit details
(define-read-only (get-letter-of-credit (loc-id uint))
  (map-get? letters-of-credit loc-id)
)

;; Read-only function to get letter of credit funds
(define-read-only (get-letter-of-credit-funds (loc-id uint))
  (map-get? loc-funds loc-id)
)

;; Function to transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (var-set admin new-admin)
    (ok true)
  )
)

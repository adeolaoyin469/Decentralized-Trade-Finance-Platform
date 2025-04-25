;; Payment Settlement Contract
;; This contract handles secure international transfers between trade parties

(define-data-var admin principal tx-sender)

;; Payment status constants
(define-constant STATUS-PENDING u1)
(define-constant STATUS-COMPLETED u2)
(define-constant STATUS-FAILED u3)
(define-constant STATUS-REFUNDED u4)

;; Map to store payment records
(define-map payments uint
  {
    sender: principal,
    receiver: principal,
    amount: uint,
    loc-id: uint,
    status: uint,
    creation-height: uint,
    completion-height: (optional uint)
  }
)

;; Map to store payment funds
(define-map payment-funds uint uint)

;; Counter for payment IDs
(define-data-var payment-id-counter uint u0)

;; Public function to initiate a payment
(define-public (initiate-payment
    (receiver principal)
    (amount uint)
    (loc-id uint))
  (let
    ((new-id (+ (var-get payment-id-counter) u1)))

    (asserts! (> amount u0) (err u1)) ;; Amount must be positive

    ;; Store the payment funds
    (map-set payment-funds new-id amount)

    ;; Record the payment
    (map-set payments new-id {
      sender: tx-sender,
      receiver: receiver,
      amount: amount,
      loc-id: loc-id,
      status: STATUS-PENDING,
      creation-height: block-height,
      completion-height: none
    })

    ;; Increment the counter
    (var-set payment-id-counter new-id)
    (ok new-id)
  )
)

;; Public function to complete a payment (only admin can call)
(define-public (complete-payment (payment-id uint))
  (let
    ((payment (unwrap! (map-get? payments payment-id) (err u2)))
     (funds (unwrap! (map-get? payment-funds payment-id) (err u5))))

    (asserts! (is-eq tx-sender (var-get admin)) (err u3)) ;; Only admin can complete
    (asserts! (is-eq (get status payment) STATUS-PENDING) (err u4)) ;; Must be pending

    ;; Clear the funds (in a real implementation, this would transfer to the receiver)
    (map-delete payment-funds payment-id)

    ;; Update payment status
    (map-set payments payment-id
      (merge payment {
        status: STATUS-COMPLETED,
        completion-height: (some block-height)
      }))

    (ok true)
  )
)

;; Public function to refund a payment (only admin can call)
(define-public (refund-payment (payment-id uint))
  (let
    ((payment (unwrap! (map-get? payments payment-id) (err u2)))
     (funds (unwrap! (map-get? payment-funds payment-id) (err u5))))

    (asserts! (is-eq tx-sender (var-get admin)) (err u3)) ;; Only admin can refund
    (asserts! (is-eq (get status payment) STATUS-PENDING) (err u4)) ;; Must be pending

    ;; Clear the funds (in a real implementation, this would transfer back to the sender)
    (map-delete payment-funds payment-id)

    ;; Update payment status
    (map-set payments payment-id
      (merge payment {
        status: STATUS-REFUNDED,
        completion-height: (some block-height)
      }))

    (ok true)
  )
)

;; Read-only function to get payment details
(define-read-only (get-payment (payment-id uint))
  (map-get? payments payment-id)
)

;; Read-only function to get payment funds
(define-read-only (get-payment-funds (payment-id uint))
  (map-get? payment-funds payment-id)
)

;; Function to transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (var-set admin new-admin)
    (ok true)
  )
)

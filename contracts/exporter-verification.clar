;; Exporter Verification Contract
;; This contract validates legitimate sellers in the trade finance platform

(define-data-var admin principal tx-sender)

;; Map to store verified exporters
(define-map verified-exporters principal
  {
    company-name: (string-utf8 100),
    country: (string-utf8 50),
    verification-date: uint,
    is-active: bool
  }
)

;; Public function to verify an exporter (only admin can call)
(define-public (verify-exporter (exporter principal) (company-name (string-utf8 100)) (country (string-utf8 50)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1)) ;; Only admin can verify
    (asserts! (is-none (map-get? verified-exporters exporter)) (err u2)) ;; Can't verify twice

    (map-set verified-exporters exporter {
      company-name: company-name,
      country: country,
      verification-date: block-height,
      is-active: true
    })
    (ok true)
  )
)

;; Public function to deactivate an exporter
(define-public (deactivate-exporter (exporter principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1)) ;; Only admin can deactivate
    (asserts! (is-some (map-get? verified-exporters exporter)) (err u3)) ;; Must exist

    ;; Get the current data and update is-active to false
    (let ((exporter-data (unwrap! (map-get? verified-exporters exporter) (err u3))))
      (map-set verified-exporters exporter
        (merge exporter-data { is-active: false }))
    )
    (ok true)
  )
)

;; Read-only function to check if an exporter is verified
(define-read-only (is-verified-exporter (exporter principal))
  (match (map-get? verified-exporters exporter)
    exporter-data (ok (get is-active exporter-data))
    (err u3)
  )
)

;; Read-only function to get exporter details
(define-read-only (get-exporter-details (exporter principal))
  (map-get? verified-exporters exporter)
)

;; Function to transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (var-set admin new-admin)
    (ok true)
  )
)

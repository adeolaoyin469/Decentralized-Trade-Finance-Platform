;; Importer Verification Contract
;; This contract validates legitimate buyers in the trade finance platform

(define-data-var admin principal tx-sender)

;; Map to store verified importers
(define-map verified-importers principal
  {
    company-name: (string-utf8 100),
    country: (string-utf8 50),
    verification-date: uint,
    is-active: bool
  }
)

;; Public function to verify an importer (only admin can call)
(define-public (verify-importer (importer principal) (company-name (string-utf8 100)) (country (string-utf8 50)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1)) ;; Only admin can verify
    (asserts! (is-none (map-get? verified-importers importer)) (err u2)) ;; Can't verify twice

    (map-set verified-importers importer {
      company-name: company-name,
      country: country,
      verification-date: block-height,
      is-active: true
    })
    (ok true)
  )
)

;; Public function to deactivate an importer
(define-public (deactivate-importer (importer principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1)) ;; Only admin can deactivate
    (asserts! (is-some (map-get? verified-importers importer)) (err u3)) ;; Must exist

    ;; Get the current data and update is-active to false
    (let ((importer-data (unwrap! (map-get? verified-importers importer) (err u3))))
      (map-set verified-importers importer
        (merge importer-data { is-active: false }))
    )
    (ok true)
  )
)

;; Read-only function to check if an importer is verified
(define-read-only (is-verified-importer (importer principal))
  (match (map-get? verified-importers importer)
    importer-data (ok (get is-active importer-data))
    (err u3)
  )
)

;; Read-only function to get importer details
(define-read-only (get-importer-details (importer principal))
  (map-get? verified-importers importer)
)

;; Function to transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (var-set admin new-admin)
    (ok true)
  )
)

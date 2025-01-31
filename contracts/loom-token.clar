;; LOOM Governance Token
(define-fungible-token loom-token)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u101))

(define-data-var token-uri (optional (string-utf8 256)) none)

(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ft-mint? loom-token amount recipient)))

(define-public (transfer (amount uint) (recipient principal))
  (ft-transfer? loom-token amount tx-sender recipient))

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance loom-token account)))

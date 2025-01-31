;; NFT for DAO membership
(define-non-fungible-token loom-membership uint)

(define-data-var last-token-id uint u0)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))

(define-public (mint (recipient principal))
  (let ((token-id (+ (var-get last-token-id) u1)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (try! (nft-mint? loom-membership token-id recipient))
    (var-set last-token-id token-id)
    (ok token-id)))

(define-public (transfer (token-id uint) (recipient principal))
  (nft-transfer? loom-membership token-id tx-sender recipient))

(use-trait proposal-trait .proposal-trait.proposal-trait)

;; Constants
(define-constant err-not-authorized (err u401))
(define-constant err-invalid-amount (err u402))
(define-constant minimum-stake u1000)

;; Data vars
(define-map proposals
  uint 
  {proposer: principal, 
   title: (string-ascii 50),
   description: (string-utf8 500),
   amount: uint,
   status: (string-ascii 20),
   votes-for: uint,
   votes-against: uint})

(define-data-var proposal-count uint u0)

;; Create new proposal
(define-public (create-proposal 
  (title (string-ascii 50))
  (description (string-utf8 500))
  (amount uint))
  (begin
    (asserts! (>= amount minimum-stake) err-invalid-amount)
    (let ((proposal-id (+ (var-get proposal-count) u1)))
      (map-set proposals proposal-id
        {proposer: tx-sender,
         title: title,
         description: description,
         amount: amount,
         status: "active",
         votes-for: u0,
         votes-against: u0})
      (var-set proposal-count proposal-id)
      (ok proposal-id))))

;; Vote on proposal
(define-public (vote (proposal-id uint) (vote-for bool))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) err-not-authorized)))
    (if vote-for
      (map-set proposals proposal-id 
        (merge proposal {votes-for: (+ (get votes-for proposal) u1)}))
      (map-set proposals proposal-id 
        (merge proposal {votes-against: (+ (get votes-against proposal) u1)})))
    (ok true)))

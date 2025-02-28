(use-trait proposal-trait .proposal-trait.proposal-trait)

;; Constants
(define-constant err-not-authorized (err u401))
(define-constant err-invalid-amount (err u402))
(define-constant err-already-voted (err u403))
(define-constant err-deadline-passed (err u404))
(define-constant err-no-membership (err u405))
(define-constant minimum-stake u1000)
(define-constant voting-period u144) ;; ~24 hours in blocks
(define-constant quorum-percentage u20) ;; 20% of total supply needed

;; Data vars
(define-map proposals
  uint 
  {proposer: principal, 
   title: (string-ascii 50),
   description: (string-utf8 500),
   amount: uint,
   status: (string-ascii 20),
   votes-for: uint,
   votes-against: uint,
   deadline: uint,
   executed: bool})

(define-map votes
  { proposal-id: uint, voter: principal }
  { weight: uint, vote-for: bool })

(define-data-var proposal-count uint u0)

;; Create new proposal
(define-public (create-proposal 
  (title (string-ascii 50))
  (description (string-utf8 500))
  (amount uint))
  (begin
    (asserts! (>= amount minimum-stake) err-invalid-amount)
    (asserts! (is-some (contract-call? .loom-membership get-balance tx-sender)) err-no-membership)
    (let ((proposal-id (+ (var-get proposal-count) u1))
          (deadline (+ block-height voting-period)))
      (map-set proposals proposal-id
        {proposer: tx-sender,
         title: title,
         description: description,
         amount: amount,
         status: "active",
         votes-for: u0,
         votes-against: u0,
         deadline: deadline,
         executed: false})
      (var-set proposal-count proposal-id)
      (ok proposal-id))))

;; Vote on proposal
(define-public (vote (proposal-id uint) (vote-for bool))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) err-not-authorized))
        (voter-balance (unwrap! (contract-call? .loom-token get-balance tx-sender) err-not-authorized)))
    (asserts! (< block-height (get deadline proposal)) err-deadline-passed)
    (asserts! (is-none (map-get? votes {proposal-id: proposal-id, voter: tx-sender})) err-already-voted)
    (asserts! (> voter-balance u0) err-not-authorized)
    
    (map-set votes {proposal-id: proposal-id, voter: tx-sender}
      {weight: voter-balance, vote-for: vote-for})
    
    (if vote-for
      (map-set proposals proposal-id 
        (merge proposal {votes-for: (+ (get votes-for proposal) voter-balance)}))
      (map-set proposals proposal-id 
        (merge proposal {votes-against: (+ (get votes-against proposal) voter-balance)})))
    (ok true)))

;; Execute proposal
(define-public (execute-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) err-not-authorized))
        (total-supply (unwrap! (contract-call? .loom-token get-total-supply) err-not-authorized))
        (quorum-requirement (* total-supply (/ quorum-percentage u100))))
    (asserts! (>= block-height (get deadline proposal)) err-not-authorized)
    (asserts! (not (get executed proposal)) err-not-authorized)
    (asserts! (>= (+ (get votes-for proposal) (get votes-against proposal)) quorum-requirement) err-not-authorized)
    
    (if (> (get votes-for proposal) (get votes-against proposal))
      (begin
        (map-set proposals proposal-id (merge proposal 
          {status: "passed",
           executed: true}))
        (ok true))
      (begin
        (map-set proposals proposal-id (merge proposal 
          {status: "rejected",
           executed: true}))
        (ok false)))))

;; Getter for proposal details
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id))

;; Getter for vote details
(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes {proposal-id: proposal-id, voter: voter}))

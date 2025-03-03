(use-trait proposal-trait .proposal-trait.proposal-trait)

;; Constants
(define-constant err-not-authorized (err u401))
(define-constant err-invalid-amount (err u402))
(define-constant err-already-voted (err u403))
(define-constant err-deadline-passed (err u404))
(define-constant err-no-membership (err u405))
(define-constant err-invalid-proposal (err u406))
(define-constant err-not-proposer (err u407))
(define-constant err-already-executed (err u408))

(define-constant minimum-stake u1000)
(define-constant voting-period u144) ;; ~24 hours in blocks
(define-constant quorum-percentage u20) ;; 20% of total supply needed
(define-constant execution-timeout u720) ;; ~5 days in blocks

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
   executed: bool,
   canceled: bool})

(define-map votes
  { proposal-id: uint, voter: principal }
  { weight: uint, vote-for: bool })

(define-map vote-delegates
  principal
  principal)

(define-data-var proposal-count uint u0)

;; Events
(define-data-var last-event-id uint u0)

(define-map events
  uint
  {event-type: (string-ascii 20),
   proposal-id: uint,
   initiator: principal,
   data: (optional (string-utf8 100))})

;; Helper functions
(define-private (emit-event (event-type (string-ascii 20)) (proposal-id uint) (data (optional (string-utf8 100))))
  (let ((event-id (+ (var-get last-event-id) u1)))
    (var-set last-event-id event-id)
    (map-set events event-id
      {event-type: event-type,
       proposal-id: proposal-id,
       initiator: tx-sender,
       data: data})
    (ok event-id)))

(define-private (get-voting-power (voter principal))
  (default-to u0
    (match (map-get? vote-delegates voter)
      delegate (contract-call? .loom-token get-balance delegate)
      (contract-call? .loom-token get-balance voter))))

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
         executed: false,
         canceled: false})
      (var-set proposal-count proposal-id)
      (try! (emit-event "proposal-created" proposal-id none))
      (ok proposal-id))))

;; Cancel proposal
(define-public (cancel-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) err-invalid-proposal)))
    (asserts! (is-eq (get proposer proposal) tx-sender) err-not-proposer)
    (asserts! (not (get executed proposal)) err-already-executed)
    (asserts! (< block-height (get deadline proposal)) err-deadline-passed)
    
    (map-set proposals proposal-id
      (merge proposal {status: "canceled", canceled: true}))
    (try! (emit-event "proposal-canceled" proposal-id none))
    (ok true)))

;; Delegate votes
(define-public (delegate-vote (delegate principal))
  (begin
    (map-set vote-delegates tx-sender delegate)
    (try! (emit-event "vote-delegated" u0 (some (concat "to: " (to-ascii delegate)))))
    (ok true)))

;; Vote on proposal
(define-public (vote (proposal-id uint) (vote-for bool))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) err-not-authorized))
        (voting-power (get-voting-power tx-sender)))
    (asserts! (< block-height (get deadline proposal)) err-deadline-passed)
    (asserts! (is-none (map-get? votes {proposal-id: proposal-id, voter: tx-sender})) err-already-voted)
    (asserts! (> voting-power u0) err-not-authorized)
    
    (map-set votes {proposal-id: proposal-id, voter: tx-sender}
      {weight: voting-power, vote-for: vote-for})
    
    (if vote-for
      (map-set proposals proposal-id 
        (merge proposal {votes-for: (+ (get votes-for proposal) voting-power)}))
      (map-set proposals proposal-id 
        (merge proposal {votes-against: (+ (get votes-against proposal) voting-power)})))
    (try! (emit-event "vote-cast" proposal-id (some (concat "weight: " (to-ascii voting-power)))))
    (ok true)))

[... rest of the contract with similar enhancements ...]

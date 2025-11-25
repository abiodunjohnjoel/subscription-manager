;; Decentralized Subscription Manager
;; Single contract to manage multiple service subscriptions with automatic payments and cancellation rights

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PLAN-NOT-FOUND (err u101))
(define-constant ERR-SUBSCRIPTION-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-SUBSCRIBED (err u103))
(define-constant ERR-PAYMENT-FAILED (err u104))
(define-constant ERR-INVALID-AMOUNT (err u105))
(define-constant ERR-INVALID-DURATION (err u106))
(define-constant ERR-SUBSCRIPTION-EXPIRED (err u107))
(define-constant ERR-PLAN-INACTIVE (err u108))

;; Data variables
(define-data-var plan-counter uint u0)
(define-data-var subscription-counter uint u0)

;; Data maps
;; Subscription Plans: plan-id -> {provider, price, duration, active}
(define-map subscription-plans
    uint
    {
        provider: principal,
        name: (string-ascii 50),
        price: uint,
        duration: uint,
        active: bool
    }
)

;; Active Subscriptions: {subscriber, plan-id} -> {start-time, payments-made, cancelled}
(define-map subscriptions
    {subscriber: principal, plan-id: uint}
    {
        start-time: uint,
        last-payment-time: uint,
        payments-made: uint,
        cancelled: bool
    }
)

;; Subscription counter per user: track how many subscriptions a user has
(define-map user-subscription-count
    principal
    uint
)

;; Public functions

;; Create a new subscription plan
(define-public (create-plan (name (string-ascii 50)) (price uint) (duration uint))
    (let
        (
            (new-plan-id (+ (var-get plan-counter) u1))
        )
        (asserts! (> price u0) ERR-INVALID-AMOUNT)
        (asserts! (> duration u0) ERR-INVALID-DURATION)

        (map-set subscription-plans
            new-plan-id
            {
                provider: tx-sender,
                name: name,
                price: price,
                duration: duration,
                active: true
            }
        )
        (var-set plan-counter new-plan-id)
        (ok new-plan-id)
    )
)

;; Subscribe to a plan
(define-public (subscribe (plan-id uint))
    (let
        (
            (plan (unwrap! (map-get? subscription-plans plan-id) ERR-PLAN-NOT-FOUND))
            (existing-sub (map-get? subscriptions {subscriber: tx-sender, plan-id: plan-id}))
        )
        ;; Check if plan is active
        (asserts! (get active plan) ERR-PLAN-INACTIVE)

        ;; Check if already subscribed and not cancelled
        (asserts!
            (or
                (is-none existing-sub)
                (get cancelled (unwrap-panic existing-sub))
            )
            ERR-ALREADY-SUBSCRIBED
        )

        ;; Process initial payment
        (try! (stx-transfer? (get price plan) tx-sender (get provider plan)))

        ;; Create subscription record
        (map-set subscriptions
            {subscriber: tx-sender, plan-id: plan-id}
            {
                start-time: u0,
                last-payment-time: u0,
                payments-made: u1,
                cancelled: false
            }
        )

        ;; Update user subscription count
        (map-set user-subscription-count
            tx-sender
            (+ (default-to u0 (map-get? user-subscription-count tx-sender)) u1)
        )

        (ok true)
    )
)

;; Process automatic payment for an existing subscription
(define-public (process-payment (subscriber principal) (plan-id uint))
    (let
        (
            (plan (unwrap! (map-get? subscription-plans plan-id) ERR-PLAN-NOT-FOUND))
            (sub (unwrap! (map-get? subscriptions {subscriber: subscriber, plan-id: plan-id}) ERR-SUBSCRIPTION-NOT-FOUND))
            (payment-count (get payments-made sub))
        )
        ;; Check subscription is not cancelled
        (asserts! (not (get cancelled sub)) ERR-SUBSCRIPTION-EXPIRED)

        ;; Check plan is still active
        (asserts! (get active plan) ERR-PLAN-INACTIVE)

        ;; Process payment from subscriber to provider
        (try! (stx-transfer? (get price plan) subscriber (get provider plan)))

        ;; Update subscription record
        (map-set subscriptions
            {subscriber: subscriber, plan-id: plan-id}
            (merge sub {
                last-payment-time: payment-count,
                payments-made: (+ payment-count u1)
            })
        )

        (ok true)
    )
)

;; Cancel a subscription
(define-public (cancel-subscription (plan-id uint))
    (let
        (
            (sub (unwrap! (map-get? subscriptions {subscriber: tx-sender, plan-id: plan-id}) ERR-SUBSCRIPTION-NOT-FOUND))
        )
        ;; Check if already cancelled
        (asserts! (not (get cancelled sub)) ERR-SUBSCRIPTION-EXPIRED)

        ;; Mark as cancelled
        (map-set subscriptions
            {subscriber: tx-sender, plan-id: plan-id}
            (merge sub {cancelled: true})
        )

        ;; Decrease user subscription count
        (map-set user-subscription-count
            tx-sender
            (- (default-to u1 (map-get? user-subscription-count tx-sender)) u1)
        )

        (ok true)
    )
)

;; Deactivate a subscription plan (only by provider)
(define-public (deactivate-plan (plan-id uint))
    (let
        (
            (plan (unwrap! (map-get? subscription-plans plan-id) ERR-PLAN-NOT-FOUND))
        )
        ;; Only provider can deactivate
        (asserts! (is-eq tx-sender (get provider plan)) ERR-NOT-AUTHORIZED)

        ;; Deactivate plan
        (map-set subscription-plans
            plan-id
            (merge plan {active: false})
        )

        (ok true)
    )
)

;; Reactivate a subscription plan (only by provider)
(define-public (reactivate-plan (plan-id uint))
    (let
        (
            (plan (unwrap! (map-get? subscription-plans plan-id) ERR-PLAN-NOT-FOUND))
        )
        ;; Only provider can reactivate
        (asserts! (is-eq tx-sender (get provider plan)) ERR-NOT-AUTHORIZED)

        ;; Reactivate plan
        (map-set subscription-plans
            plan-id
            (merge plan {active: true})
        )

        (ok true)
    )
)

;; Read-only functions

;; Get subscription plan details
(define-read-only (get-plan (plan-id uint))
    (ok (map-get? subscription-plans plan-id))
)

;; Get subscription details
(define-read-only (get-subscription (subscriber principal) (plan-id uint))
    (ok (map-get? subscriptions {subscriber: subscriber, plan-id: plan-id}))
)

;; Check if subscription is active
(define-read-only (is-subscription-active (subscriber principal) (plan-id uint))
    (match (map-get? subscriptions {subscriber: subscriber, plan-id: plan-id})
        sub (ok (not (get cancelled sub)))
        (ok false)
    )
)

;; Get total active subscriptions for a user
(define-read-only (get-user-subscription-count (user principal))
    (ok (default-to u0 (map-get? user-subscription-count user)))
)

;; Get current plan counter
(define-read-only (get-plan-counter)
    (ok (var-get plan-counter))
)

;; Get current subscription counter
(define-read-only (get-subscription-counter)
    (ok (var-get subscription-counter))
)

;; Check if subscription is valid (not cancelled and plan is active)
(define-read-only (is-subscription-valid (subscriber principal) (plan-id uint))
    (match (map-get? subscriptions {subscriber: subscriber, plan-id: plan-id})
        sub (match (map-get? subscription-plans plan-id)
            plan (ok (and
                (not (get cancelled sub))
                (get active plan)
            ))
            (ok false)
        )
        (ok false)
    )
)

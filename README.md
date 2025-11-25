Decentralized Subscription Manager

Overview

The Decentralized Subscription Manager is a Clarity smart contract that enables service providers to create and manage subscription-based services on-chain. Users can subscribe to multiple plans, make automatic recurring payments, and cancel subscriptions at any time. Providers can activate or deactivate plans while subscribers maintain full autonomy and transparency over their active services.

The contract manages:

Subscription plan creation

User subscriptions

Automated recurring payments

Cancellation rights

Tracking subscription counts per user

Plan activation and deactivation

This makes it suitable for:

SaaS billing

Content subscription platforms

Periodic token-gated access

Multi-provider marketplaces

Key Features
✔ Plan Creation

Providers can create subscription plans with:

Name

Price (in STX)

Duration

Active/inactive status

✔ User Subscriptions

Subscribers can:

Subscribe to any active plan

Pay automatically on each cycle

View their subscription status

Cancel at any time

✔ Automatic Payments

A provider or an external automation tool can call process-payment to:

Charge subscribers

Update payment counts

Record timing metadata

✔ Plan Lifecycle

Providers can:

Deactivate plans (no new subscriptions allowed)

Reactivate plans

✔ User Analytics

The system tracks:

Total subscription plans created

Active subscriptions per user

Contract Data Structure
Maps
Map Name	Key	Value	Purpose
subscription-plans	plan-id	provider, name, price, duration, active	Stores all plan definitions
subscriptions	{subscriber, plan-id}	start-time, last-payment-time, payments-made, cancelled	Tracks user subscriptions
user-subscription-count	principal	uint	Tracks the number of active subscriptions per user
Public Functions
1. create-plan

Creates a new subscription plan.
Validates:

price > 0

duration > 0

Returns the new plan ID.

2. subscribe

Allows a user to subscribe to a plan:

Validates plan is active

Prevents duplicate active subscriptions

Transfers initial payment

Creates subscription record

Updates user subscription count

3. process-payment

Processes a recurring subscription payment:

Validates subscription exists and is active

Ensures plan is still active

Transfers payment

Updates payment metadata

4. cancel-subscription

Cancels a subscription:

Ensures subscription exists

Prevents double cancellation

Marks subscription as cancelled

Decrements user subscription count

5. deactivate-plan / reactivate-plan

Provider-only administrative actions.

Read-Only Functions

| Function | Description |
|=========|-------------|
| get-plan | Retrieves details of a subscription plan |
| get-subscription | Retrieves a specific subscription record |
| is-subscription-active | Checks if a subscription is active (not cancelled) |
| get-user-subscription-count | Number of active subscriptions for a user |
| get-plan-counter | Returns total number of plans ever created |
| get-subscription-counter | (Reserved for future use) |
| is-subscription-valid | Active subscription AND active plan |

Error Codes
Error	Code	Meaning
ERR-NOT-AUTHORIZED	100	Only provider allowed
ERR-PLAN-NOT-FOUND	101	Plan does not exist
ERR-SUBSCRIPTION-NOT-FOUND	102	Subscription not found
ERR-ALREADY-SUBSCRIBED	103	Cannot resubscribe unless cancelled
ERR-PAYMENT-FAILED	104	STX transfer failed
ERR-INVALID-AMOUNT	105	Price must be > 0
ERR-INVALID-DURATION	106	Duration must be > 0
ERR-SUBSCRIPTION-EXPIRED	107	Subscription already cancelled
ERR-PLAN-INACTIVE	108	Cannot subscribe or charge inactive plan
Example Usage
Create a plan
(contract-call? .sub-manager create-plan "Pro Plan" u100 u30)

Subscribe to a plan
(contract-call? .sub-manager subscribe u1)

Process recurring payment
(contract-call? .sub-manager process-payment tx-sender u1)

Cancel subscription
(contract-call? .sub-manager cancel-subscription u1)

Security Considerations

All payments are processed through on-chain stx-transfer? to prevent unauthorized withdrawals.

Providers cannot charge subscribers without explicit subscriptions.

Cancellation rights always remain with the subscriber.

Contracts do not store STX, reducing custodial risk.

Subscription inactivity depends on both plan status and cancellation flag.
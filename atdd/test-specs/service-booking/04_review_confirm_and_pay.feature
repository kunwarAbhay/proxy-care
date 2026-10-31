# Screen: B4 Review · Confirm & Pay (User app) + shared gateway payment pattern
# Source: proxy-care-api-context.md (PRD v2.3) §4 B4, §3 "Shared payment pattern", §2 pricing,
#         booking state, cancellation policy; §7 payment states
# v2.3: Confirm & Pay redirects to a third-party payment gateway. The booking sits in
#       PAYMENT_PENDING until the gateway confirms, then moves to WAITING and is broadcast.
# Pricing: (wage x 3 h) + ₹400 margin + ₹99 platform fee

@user-app @service-booking @B4 @payments
Feature: Review booking, accept policy and pay through the payment gateway
  As a User
  I want to review every detail and the exact charge, then pay securely
  So that my booking is confirmed and sent to caretakers

  Background:
    Given today is "2026-10-31"
    And I am logged in to the User app as "Rohan Mehta"
    And I have filled a booking draft:
      | field        | value                                |
      | patient      | Kamla Mehta (Mother)                 |
      | mobility     | WHEELCHAIR                           |
      | date         | 2026-11-02                           |
      | purposes     | OPD, DIAGNOSTICS                     |
      | hospital     | Max Super Speciality Hospital, Saket |
      | department   | Cardiology                           |
      | pickup_time  | 09:30 AM                             |
      | instructions | Carry old reports                    |
      | attachments  | prescription.jpg                     |

  # ---------- Display ----------

  @smoke
  Scenario: Review screen shows all booking details with Edit links
    When I open the "B4 Review · Confirm & Pay" screen
    Then I should see the following sections, each with an "Edit" link:
      | section      | value                                      |
      | Patient      | Kamla Mehta                                |
      | Date         | Mon, 2 Nov                                 |
      | Purposes     | OPD / Consultation, Diagnostics            |
      | Hospital     | Max Super Speciality Hospital · Cardiology |
      | Pickup time  | 09:30 AM                                   |
      | Instructions | Carry old reports                          |
      | Attachments  | prescription.jpg                           |

  @smoke
  Scenario Outline: Price breakdown follows the patient's mobility category
    Given the patient's mobility is "<mobility>"
    When I open the "B4 Review · Confirm & Pay" screen
    Then the price breakdown should show:
      | line                   | amount  |
      | Caretaker <wage> × 3 h | <block> |
      | Platform margin & risk | ₹400    |
      | Platform fee           | ₹99     |
      | Total                  | <total> |
    And the primary button should read "Confirm & Pay <total>"

    Examples:
      | mobility   | wage | block | total  |
      | AMBULATORY | ₹200 | ₹600  | ₹1,099 |
      | WHEELCHAIR | ₹250 | ₹750  | ₹1,249 |
      | BEDRIDDEN  | ₹320 | ₹960  | ₹1,459 |

  @smoke
  Scenario Outline: Cancellation policy shows the refund to bank for each case
    Given the patient's mobility is "<mobility>"
    When I open the "B4 Review · Confirm & Pay" screen
    Then the cancellation policy should say refunds go to my bank account or original payment method
    And the cancellation policy should show:
      | case                        | refund         |
      | More than 8 h before pickup | <refund_early> |
      | Less than 8 h before pickup | <refund_late>  |
      | No-show                     | No refund      |

    Examples:
      | mobility   | refund_early | refund_late |
      | AMBULATORY | ₹1,000       | ₹400        |
      | WHEELCHAIR | ₹1,150       | ₹400        |
      | BEDRIDDEN  | ₹1,360       | ₹400        |

  # ---------- Policy checkbox ----------

  @negative
  Scenario: Confirm & Pay is disabled until the policy checkbox is ticked
    When I open the "B4 Review · Confirm & Pay" screen
    Then the "I've read the cancellation policy" checkbox should be unticked
    And the "Confirm & Pay ₹1,249" button should be disabled

  @negative
  Scenario: Unticking the policy checkbox disables Confirm & Pay again
    Given I am on the "B4 Review · Confirm & Pay" screen
    And I have ticked "I've read the cancellation policy"
    When I untick "I've read the cancellation policy"
    Then the "Confirm & Pay ₹1,249" button should be disabled

  # ---------- Happy path: gateway ----------

  @smoke @happy-path
  Scenario: Pay successfully through the gateway
    Given I am on the "B4 Review · Confirm & Pay" screen
    And I have ticked "I've read the cancellation policy"
    When I tap "Confirm & Pay ₹1,249"
    Then I should see the "Opening secure payment" sheet
    And a booking should be created in state "PAYMENT_PENDING"
    And a gateway order for "₹1,249" should be created for that booking
    And I should be redirected to the payment gateway page
    When I complete the payment of "₹1,249" on the gateway
    And I return to the app
    Then I should see the success message "₹1,249 paid" with a "Continue" button
    And the booking state should be "WAITING"
    And the booking code should look like "PC-####"
    And the price breakdown should be frozen on the booking
    When I tap "Continue"
    Then I should be on the "B5 Finding caretaker" screen

  @happy-path @realtime
  Scenario: Booking is broadcast only after payment is confirmed
    Given I have tapped "Confirm & Pay ₹1,249" and been redirected to the gateway
    Then no caretaker should have received a request for the booking
    When the gateway confirms the payment
    Then the booking should be broadcast to nearby caretakers

  # ---------- Gateway failure / cancel ----------

  @negative
  Scenario: Payment fails at the gateway
    Given I am on the "B4 Review · Confirm & Pay" screen
    And I have ticked "I've read the cancellation policy"
    And I have tapped "Confirm & Pay ₹1,249"
    When the payment fails on the gateway
    And I return to the app
    Then I should see a payment failed message with a "Retry payment" button
    And the booking state should be "PAYMENT_PENDING"
    And the booking should not be broadcast to caretakers
    And all my booking details should be unchanged

  @negative
  Scenario: User cancels on the gateway page
    Given I have tapped "Confirm & Pay ₹1,249" and been redirected to the gateway
    When I cancel the payment on the gateway
    And I return to the app
    Then I should be back on the "B4 Review · Confirm & Pay" screen
    And I should see the message "Payment cancelled. You have not been charged."
    And the "Confirm & Pay ₹1,249" button should be enabled

  @happy-path
  Scenario: Retry after a failed payment succeeds
    Given my first payment attempt for the booking failed
    When I tap "Retry payment"
    And I complete the payment of "₹1,249" on the gateway
    And I return to the app
    Then I should see "₹1,249 paid"
    And the booking state should be "WAITING"
    And I should have been charged "₹1,249" only once

  @error
  Scenario: Gateway order cannot be created
    Given I am on the "B4 Review · Confirm & Pay" screen
    And I have ticked "I've read the cancellation policy"
    And the create-order API returns a server error
    When I tap "Confirm & Pay ₹1,249"
    Then I should not be redirected to the gateway
    And I should see the error "Couldn't start payment. Please try again."
    And the "Confirm & Pay ₹1,249" button should be enabled

  # ---------- Resume / idempotency ----------

  @ui-state
  Scenario: Redirecting state blocks double taps
    Given I am on the "B4 Review · Confirm & Pay" screen
    And I have ticked "I've read the cancellation policy"
    And the create-order API responds slowly
    When I tap "Confirm & Pay ₹1,249"
    Then the "Confirm & Pay ₹1,249" button should show a spinner and be disabled
    And the Edit links and back button should be disabled
    When I tap "Confirm & Pay ₹1,249" again
    Then only one gateway order should be created

  @ui-state
  Scenario: App resumed mid-payment polls for status
    Given I was redirected to the gateway for booking "PC-2481"
    And the app was sent to the background
    When I reopen the app before the gateway result is known
    Then I should see "Checking payment status"
    When the gateway webhook reports the payment as successful
    Then I should see "₹1,249 paid"
    And the booking state should be "WAITING"

  @error
  Scenario: Paid at gateway but the app was killed before returning
    Given I completed the payment on the gateway for booking "PC-2481"
    And the app was closed before it returned from the gateway
    When I reopen the app
    Then the app should fetch the payment status for "PC-2481"
    And I should be taken to the "B5 Finding caretaker" screen for "PC-2481"
    And I should not be asked to pay again

  @error
  Scenario: Gateway webhook arrives twice
    Given the gateway sends the same payment success webhook twice for booking "PC-2481"
    Then booking "PC-2481" should be broadcast to caretakers only once
    And only one payment should be recorded for "PC-2481"

  @error
  Scenario: Price changed since the draft was built
    Given the hourly wage for "WHEELCHAIR" changed on the server since I opened the screen
    And I have ticked "I've read the cancellation policy"
    When I tap "Confirm & Pay ₹1,249"
    Then I should see a dialog "Price updated" with the new total
    And I should not be redirected to the gateway until I confirm the new total

  # ---------- Edit links ----------

  @navigation
  Scenario Outline: Edit links go to the right step and return to review
    Given I am on the "B4 Review · Confirm & Pay" screen
    When I tap "Edit" on the "<section>" section
    Then I should be on the "<screen>" screen with my previous inputs prefilled
    When I change the value and save
    Then I should return to the "B4 Review · Confirm & Pay" screen with the updated value

    Examples:
      | section      | screen                                 |
      | Date         | B2 Visit date & purposes               |
      | Purposes     | B2 Visit date & purposes               |
      | Hospital     | B3 Hospital, pickup time & attachments |
      | Pickup time  | B3 Hospital, pickup time & attachments |
      | Instructions | B3 Hospital, pickup time & attachments |
      | Attachments  | B3 Hospital, pickup time & attachments |

  @navigation
  Scenario: Edit patient goes back to patient selection
    Given I am on the "B4 Review · Confirm & Pay" screen
    When I tap "Edit" on the "Patient" section
    Then I should be on the "B1 Home" screen with "Kamla Mehta" selected

  @navigation
  Scenario: Changing patient to a different mobility recalculates price
    Given I am on the "B4 Review · Confirm & Pay" screen showing total "₹1,249"
    When I change the patient to "Suresh Mehta" with mobility "AMBULATORY"
    And I return to the "B4 Review · Confirm & Pay" screen
    Then the total should be "₹1,099"
    And the primary button should read "Confirm & Pay ₹1,099"
    And the cancellation policy checkbox should be unticked

  @navigation
  Scenario: Back button returns to B3 without creating a booking or charge
    Given I am on the "B4 Review · Confirm & Pay" screen
    When I tap the back button
    Then I should be on the "B3 Hospital, pickup time & attachments" screen
    And no booking should be created
    And no gateway order should be created

  @pending-design
  Scenario: Dedicated payment-failed screen
    Given the payment failed on the gateway
    When I return to the app
    Then I should see the designed payment-failed screen

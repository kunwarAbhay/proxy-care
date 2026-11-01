# Screen: U2b Ride payment request (User app)
# Source: proxy-care-ui-ux-state-for-api-design.md (PRD v2.3) §4 U2b, §3 shared payment pattern, §2 payment request status, §7 realtime, §8 payment states; PRD 3.2
# Gateway failure messages reuse the wording in hospital-appointment/03_user_hospital_payment_request.feature, as both follow §3.
# U3b (ride home) has the same contract and belongs to the drop-off phase.

@user-app @pickup-and-ride @U2b @payments
Feature: User approves and pays the ride to the hospital
  As the User sponsoring a visit
  I want to review the ride fare and pay it through the gateway
  So that the caretaker never has to use their own money

  Rules (context §2, §3, §4):
    - Payment request status: REQUESTED -> PAYING -> PAID / FAILED (retry).
    - DISPUTED applies to hospital bills only, so U2b has no dispute action.
    - Every charge goes through the third-party gateway (redirect, then return to the app).
    - Repeat taps on "Approve & Pay" must be idempotent.
    - After paying, Continue opens H6.

  Background:
    Given I am logged in to the User app as "Rohan Mehta"
    And booking "PC-2481" for patient "Kamla Mehta" is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And caretaker "Anita Verma" is assigned to booking "PC-2481"
    And the ride for leg "TO_HOSPITAL" has the driver "Sunil Yadav" and the latest event "TRIP_COMPLETED"
    And a "RIDE_TO_HOSPITAL" payment request for "₹340" with description "Ride to hospital" exists for booking "PC-2481"

  # ---------- Arrival on U2b ----------

  @smoke @navigation
  Scenario: Opening the request from the pending list on Home
    When I open the "B1 Home" screen
    Then the "Pending payment requests" section should show the row "Ride to hospital" with the amount "₹340"
    When I tap that row
    Then I should be on the "U2b Ride payment request" screen

  @navigation
  Scenario: Opening the request from a push notification
    Given the app is in the background
    And I received a push notification about the "₹340" ride payment request
    When I tap the notification
    Then the User app should open on the "U2b Ride payment request" screen

  @navigation
  Scenario: An old notification for a paid request opens the paid state
    Given the payment request status is "PAID"
    When I tap the old notification for that request
    Then I should be on the "U2b Ride payment request" screen
    And I should see the status chip "Paid"
    And the "Approve & Pay" button should not be visible

  # ---------- Display ----------

  @smoke
  Scenario: U2b shows the amount and the trip details
    When I open the "U2b Ride payment request" screen
    Then I should see the amount "₹340"
    And I should see the status chip "Requested"
    And I should see the ride details
    And I should see the trip route to the hospital
    And I should see the trip time
    And I should see the driver "Sunil Yadav"
    And I should see the "Approve & Pay ₹340" button
    And I should see the action "Call caretaker"

  @negative
  Scenario: A ride fare cannot be disputed on U2b
    When I open the "U2b Ride payment request" screen
    Then I should not see a "This bill looks wrong" link

  @happy-path
  Scenario: Call caretaker opens the dialer
    Given I am on the "U2b Ride payment request" screen
    When I tap "Call caretaker"
    Then the phone dialer should open with the number of "Anita Verma"

  # ---------- Approve & Pay ----------

  @smoke @happy-path
  Scenario: Paying the ride successfully
    Given I am on the "U2b Ride payment request" screen
    When I tap "Approve & Pay ₹340"
    Then I should see the "Opening secure payment" sheet
    And the payment request status should be "PAYING"
    And I should be redirected to the payment gateway page for "₹340"
    When I complete the payment on the gateway
    And I return to the app
    Then I should see the success message "₹340 paid"
    And I should see a "Continue" button
    And the payment request status should be "PAID"
    And the caretaker should see "Rohan paid" on the "P9a Ride payment" screen
    When I tap "Continue"
    Then I should be on the "H6 Services status" screen
    And the "Pending payment requests" section on Home should not show the "₹340" request

  @happy-path
  Scenario: A paid ride appears in Payments with its route and receipt
    Given the "₹340" ride payment request is paid
    When I open the "B8 Payments" screen
    Then the row "Ride to hospital" should show the amount "₹340" and "Paid" under visit "PC-2481"
    When I tap that row
    Then I should be on the "B9 Payment details" screen
    And I should see the route, method and transaction id
    And I should see the ride trip receipt in the "Bills" section

  @negative
  Scenario Outline: Gateway does not complete the payment
    Given I am on the "U2b Ride payment request" screen
    When I tap "Approve & Pay ₹340"
    And the gateway returns "<gateway_result>"
    Then I should see the message "<message>"
    And I should see a "Try again" button
    And the payment request status should be "<status>"
    And the caretaker should not see "Rohan paid"

    Examples:
      | gateway_result    | message                             | status    |
      | payment failed    | Payment failed. No money was taken. | FAILED    |
      | cancelled by user | Payment cancelled                   | REQUESTED |
      | bank declined     | Your bank declined the payment      | FAILED    |
      | session timed out | Payment session expired             | FAILED    |

  @negative
  Scenario: Retrying after a failed payment
    Given my last payment for the "₹340" ride request failed
    When I tap "Try again"
    Then a new gateway order should be created for the same payment request
    And I should be redirected to the payment gateway page for "₹340"
    When I complete the payment on the gateway
    And I return to the app
    Then I should see the success message "₹340 paid"

  @negative
  Scenario: A failed request stays in the pending list
    Given my last payment for the "₹340" ride request failed
    When I open the "B1 Home" screen
    Then the "Pending payment requests" section should show the row "Ride to hospital" with the amount "₹340"

  @ui-state
  Scenario: App resumed mid-payment polls for the final status
    Given I tapped "Approve & Pay ₹340" and was redirected to the gateway
    And the app was killed while I was on the gateway
    When I reopen the User app
    Then I should see that the payment status is being checked
    When the gateway webhook confirms the payment
    Then I should see the success message "₹340 paid"

  @ui-state
  Scenario: Payment still unconfirmed after the polling window
    Given I returned from the gateway
    And the gateway has not confirmed the payment within the polling window
    Then I should see that the payment is being confirmed
    And the "Approve & Pay" button should not be visible
    And I should not be able to start a second payment for this request

  @negative
  Scenario: Repeated taps on Approve & Pay create one gateway order
    Given I am on the "U2b Ride payment request" screen
    When I tap "Approve & Pay ₹340" 3 times quickly
    Then exactly one gateway order should be created for the payment request
    And the "Approve & Pay ₹340" button should show a loader and be disabled

  @negative
  Scenario: Gateway order creation fails before redirect
    Given the create gateway order request will fail
    And I am on the "U2b Ride payment request" screen
    When I tap "Approve & Pay ₹340"
    Then I should see an error
    And I should remain on the "U2b Ride payment request" screen
    And the payment request status should be "REQUESTED"

  @negative
  Scenario: Paying a request already paid on another device
    Given the "₹340" ride request was paid from my other device
    And I am still on the "U2b Ride payment request" screen on this device
    When I tap "Approve & Pay ₹340"
    Then no gateway order should be created
    And the screen should refresh to the "Paid" state

  # ---------- State matrix ----------

  Scenario Outline: Screen controls per payment request status
    Given the payment request status is "<status>"
    When I open the "U2b Ride payment request" screen
    Then I should see the status chip "<chip>"
    And the "Approve & Pay" button should be <pay>
    And the "Continue" button should be <continue>

    Examples:
      | status    | chip      | pay                    | continue |
      | REQUESTED | Requested | enabled                | hidden   |
      | PAYING    | Paying    | shown with a loader    | hidden   |
      | FAILED    | Failed    | enabled as "Try again" | hidden   |
      | PAID      | Paid      | hidden                 | enabled  |

  # ---------- Loading / error / offline ----------

  @ui-state
  Scenario: Skeleton while the request loads
    Given the payment request is slow to load
    When I open the "U2b Ride payment request" screen
    Then I should see skeleton placeholders

  @ui-state @negative
  Scenario: Error state with retry when the request fails to load
    Given the payment request fails to load
    When I open the "U2b Ride payment request" screen
    Then I should see an error with a "Retry" button
    When the payment request loads successfully
    And I tap "Retry"
    Then I should see the amount "₹340"

  @ui-state @negative
  Scenario: Offline banner blocks payment
    Given I am on the "U2b Ride payment request" screen
    When the device goes offline
    Then I should see an offline banner
    And the "Approve & Pay ₹340" button should be disabled
    When the device comes back online
    Then the "Approve & Pay ₹340" button should be enabled

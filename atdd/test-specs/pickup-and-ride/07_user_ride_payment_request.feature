# Screen: U2b Ride payment request (User app)
# Source: proxy-care-ui-ux-state-for-api-design.md (PRD v2.3) §4 U2b, §3 shared payment pattern, §2 payment request status, §6 B1 query, §7 realtime, §8 payment states; PRD 3.2
# Gateway failure messages reuse the wording in hospital-appointment/03_user_hospital_payment_request.feature, as both follow §3.
# U3b (ride home) has the same contract and belongs to the drop-off phase.

@regression @user-app @pickup-and-ride @U2b @payments
Feature: User approves and pays the ride to the hospital
  As the User sponsoring a visit
  I want to review the ride fare and pay it through the gateway
  So that the caretaker never has to use their own money

  Rules (context §2, §3, §4, §6):
    - Payment request status: REQUESTED -> PAYING -> PAID / FAILED (retry).
    - DISPUTED applies to hospital bills only, so U2b has no dispute action.
    - Every charge goes through the third-party gateway (redirect, then return to the app).
    - Repeat taps on "Approve & Pay" must be idempotent.
    - After paying, Continue opens H6.
    - The B1 pending list shows requests with status REQUESTED or FAILED.

  Background:
    Given I am logged in to the User app as "Rohan Mehta"
    And my booking "PC-2481" for patient "Kamla Mehta" has the caretaker "Anita Verma"
    And the booking is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And the ride has the driver "Sunil Yadav" and the latest event "TRIP_COMPLETED"
    And the booking has a "RIDE_TO_HOSPITAL" payment request for "₹340" with description "Ride to hospital"

  # ---------- Arrival on U2b ----------

  @smoke @navigation
  Scenario: The pending list on Home opens the request
    Given the ride payment request has status "REQUESTED"
    And I am on the "B1 Home" screen
    When I open the pending payment request "Ride to hospital"
    Then I should be on the "U2b Ride payment request" screen

  @navigation @device
  Scenario: A push notification opens the request
    Given the ride payment request has status "REQUESTED"
    And the app is in the background
    When I tap the ride payment request notification
    Then I should be on the "U2b Ride payment request" screen

  @navigation @device
  Scenario: An old notification for a paid request opens the paid state
    Given the ride payment request has status "PAID"
    And the app is in the background
    When I tap the ride payment request notification
    Then I should be on the "U2b Ride payment request" screen
    And I should see the status chip "Paid"
    And the "Approve & Pay" button should be hidden

  @ui-validation
  Scenario Outline: The pending list on Home depends on the request status
    Given the ride payment request has status "<status>"
    When I open the "B1 Home" screen
    Then the pending payment request "Ride to hospital" should be <listed>

    Examples:
      | status    | listed  |
      | REQUESTED | visible |
      | FAILED    | visible |
      | PAYING    | hidden  |
      | PAID      | hidden  |

  @realtime
  Scenario: A new ride request updates the Home pending count
    Given the booking has no payment requests
    And I am on the "B1 Home" screen
    When the caretaker requests the ride fare
    Then the pending payment requests count should be 1 without a refresh

  # ---------- Display ----------

  @smoke @happy-path
  Scenario: U2b shows the amount and the trip details
    Given the ride payment request has status "REQUESTED"
    When I open the "U2b Ride payment request" screen
    Then I should see the text "₹340"
    And I should see the status chip "Requested"
    And I should see the ride vehicle
    And I should see the trip route and time
    And I should see the text "Sunil Yadav"
    And the "Approve & Pay ₹340" button should be enabled
    And the "Call caretaker" button should be enabled

  @negative
  Scenario: A ride fare cannot be disputed on U2b
    Given the ride payment request has status "REQUESTED"
    When I open the "U2b Ride payment request" screen
    Then I should not see the text "This bill looks wrong"

  @happy-path @device
  Scenario: Call caretaker opens the dialer
    Given I am on the "U2b Ride payment request" screen
    When I tap "Call caretaker"
    Then the phone dialer should open with the number of "Anita Verma"

  # ---------- Approve & Pay ----------


  @smoke @happy-path
  Scenario: Returning after a successful payment shows success
    Given I have been redirected to the gateway for the ride payment request
    When I complete the payment on the gateway
    Then I should see the text "₹340 paid"
    And the "Continue" button should be enabled
    And the ride payment request should have status "PAID"
    And the caretaker should see the text "Rohan paid" on the "P9a Ride payment" screen

  @smoke @navigation
  Scenario: Continue after payment opens the services status
    Given I have just paid the ride payment request
    When I tap "Continue"
    Then I should be on the "H6 Services status" screen

  @happy-path
  Scenario: A paid ride appears in Payments
    Given the ride payment request has status "PAID"
    When I open the "B8 Payments" screen
    Then I should see the payment "Ride to hospital" for "₹340" under visit "PC-2481"

  @happy-path
  Scenario: Payment details show the route and the trip receipt
    Given the ride payment request has status "PAID"
    When I open the "B9 Payment details" screen for "Ride to hospital"
    Then I should see the route, method and transaction id
    And I should see the trip receipt in the "Bills" section

  @negative
  Scenario Outline: The gateway does not complete the payment
    Given I have been redirected to the gateway for the ride payment request
    When the gateway returns "<gateway_result>"
    Then I should see the text "<message>"
    And the "Try again" button should be enabled
    And the ride payment request should have status "<status>"
    And the caretaker should not see the text "Rohan paid"

    Examples:
      | gateway_result    | message                             | status    |
      | payment failed    | Payment failed. No money was taken. | FAILED    |
      | cancelled by user | Payment cancelled                   | REQUESTED |
      | bank declined     | Your bank declined the payment      | FAILED    |
      | session timed out | Payment session expired             | FAILED    |

  @negative
  Scenario: Try again creates a new order for the same request
    Given the ride payment request has status "FAILED"
    And I am on the "U2b Ride payment request" screen
    When I tap "Try again"
    Then a new gateway order should be created for the same payment request
    And I should be redirected to the gateway for "₹340"

  @ui-state @device
  Scenario: A resumed app shows that the payment is being checked
    Given the ride payment request has status "PAYING"
    And the gateway has not confirmed the payment
    When I force close and reopen the app
    Then I should see the "checking payment" state

  @ui-state
  Scenario: A confirmation during the check shows success
    Given I am in the "checking payment" state for the ride payment request
    When the gateway confirms the sponsoring user's payment
    Then I should see the text "₹340 paid" without a refresh

  @ui-state
  Scenario: An unconfirmed payment cannot be paid again
    Given I returned from the gateway for the ride payment request
    When the polling window passes without a gateway confirmation
    Then I should see the "payment being confirmed" state
    And the "Approve & Pay" button should be hidden

  @negative
  Scenario: Repeated taps on Approve & Pay create one gateway order
    Given the ride payment request has status "REQUESTED"
    And I am on the "U2b Ride payment request" screen
    When I tap "Approve & Pay ₹340" 3 times quickly
    Then exactly 1 "create gateway order" request should be sent
    And the "Approve & Pay ₹340" button should be loading

  @negative
  Scenario: Gateway order creation fails before the redirect
    Given the ride payment request has status "REQUESTED"
    And the "create gateway order" request will fail
    And I am on the "U2b Ride payment request" screen
    When I tap "Approve & Pay ₹340"
    Then I should see the "error" state
    And I should be on the "U2b Ride payment request" screen
    And the ride payment request should have status "REQUESTED"

  @negative
  Scenario: Paying a request already paid on another device
    Given the ride payment request has status "REQUESTED"
    And I am on the "U2b Ride payment request" screen
    And the request has since been paid on another device
    When I tap "Approve & Pay ₹340"
    Then no gateway order should be created
    And I should see the status chip "Paid"

  # ---------- State matrix ----------

  @ui-state
  Scenario Outline: Screen controls per payment request status
    Given the ride payment request has status "<status>"
    When I open the "U2b Ride payment request" screen
    Then I should see the status chip "<chip>"
    And the "Approve & Pay" button should be <pay>
    And the "Try again" button should be <retry>

    Examples:
      | status    | chip      | pay     | retry   |
      | REQUESTED | Requested | enabled | hidden  |
      | FAILED    | Failed    | hidden  | enabled |
      | PAID      | Paid      | hidden  | hidden  |

  # ---------- Loading / error / offline ----------

  @ui-state
  Scenario: Skeleton while the request loads
    Given the "ride payment request" request is slow
    When I open the "U2b Ride payment request" screen
    Then I should see the "loading skeleton" state

  @ui-state @negative
  Scenario: A failed load shows an error with Retry
    Given the "ride payment request" request will fail
    When I open the "U2b Ride payment request" screen
    Then I should see the "error" state
    And the "Retry" button should be enabled

  @ui-state
  Scenario: Retry reloads the request
    Given the "ride payment request" request failed on the "U2b Ride payment request" screen
    And the "ride payment request" request has recovered
    When I tap "Retry"
    Then I should see the text "₹340"

  @ui-state @negative
  Scenario: Going offline blocks payment
    Given the ride payment request has status "REQUESTED"
    And I am on the "U2b Ride payment request" screen
    When the device goes offline
    Then I should see the "offline banner" state
    And the "Approve & Pay ₹340" button should be disabled

  @ui-state
  Scenario: Coming back online enables payment again
    Given the ride payment request has status "REQUESTED"
    And I am on the "U2b Ride payment request" screen
    And the device is offline
    When the device comes back online
    Then the "Approve & Pay ₹340" button should be enabled

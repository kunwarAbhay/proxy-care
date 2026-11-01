# Screen: P9a Ride payment (Caretaker app)
# Source: proxy-care-ui-ux-state-for-api-design.md (PRD v2.3) §5 P9a, §2 payment request status + visit stage, §7 realtime; PRD 3.2
# Continue -> H1 is also asserted in hospital-appointment/01_caretaker_services_todo.feature.
# The drop-off equivalent (D4a) belongs to the drop-off phase and is not covered here.

@caretaker-app @pickup-and-ride @P9a @payments
Feature: Caretaker waits for the family to pay for the ride
  As a Caretaker who has reached the hospital by ride
  I want to see whether the family has paid the fare
  So that I can continue to the hospital services without using my own money

  Rules (context §2, §5, §7):
    - P9a shows the fare, the driver and "Payment request sent to {User}", which changes to "{User} paid".
    - Continue is enabled only once the payment request is PAID, and opens H1.
    - The caretaker never pays with their own money.

  Background:
    Given today is "2026-11-02"
    And I am logged in to the Caretaker app as "Anita Verma" with KYC "APPROVED"
    And I am assigned to booking "PC-2481" for patient "Kamla Mehta"
    And booking "PC-2481" is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And the sponsoring user is "Rohan Mehta", relation "Son"
    And the ride for leg "TO_HOSPITAL" has the driver "Sunil Yadav" and the latest event "TRIP_COMPLETED"
    And a "RIDE_TO_HOSPITAL" payment request for "₹340" exists for booking "PC-2481"

  # ---------- Display ----------

  @smoke
  Scenario: P9a shows the fare and that the request was sent
    Given the payment request status is "REQUESTED"
    When I open the "P9a Ride payment" screen
    Then I should see the fare "₹340"
    And I should see the driver "Sunil Yadav"
    And I should see "Payment request sent to Rohan"
    And I should see the action "Remind family"
    And the "Continue" button should be disabled

  Scenario Outline: Continue and the status text follow the payment request status
    Given the payment request status is "<status>"
    When I open the "P9a Ride payment" screen
    Then I should <paid> "Rohan paid"
    And the "Continue" button should be <continue>

    Examples:
      | status    | paid    | continue |
      | REQUESTED | not see | disabled |
      | PAYING    | not see | disabled |
      | FAILED    | not see | disabled |
      | PAID      | see     | enabled  |

  @access-control @security
  Scenario: The caretaker has no way to pay and sees no payment details
    Given the payment request status is "PAID"
    When I open the "P9a Ride payment" screen
    Then I should not see any option to pay the fare myself
    And I should not see the card, UPI handle or bank of the payment
    And my earnings wallet balance should be unchanged

  # ---------- Family pays ----------

  @smoke @happy-path @realtime
  Scenario: The screen updates when the family pays
    Given the payment request status is "REQUESTED"
    And I am on the "P9a Ride payment" screen
    When "Rohan Mehta" completes the payment on the gateway
    Then I should see "Rohan paid" without a manual refresh
    And the "Continue" button should be enabled
    When I tap "Continue"
    Then I should be on the "H1 Services to-do" screen
    And the visit stage of booking "PC-2481" should be "AT_HOSPITAL"

  @negative @realtime
  Scenario: A failed family payment keeps Continue disabled
    Given the payment request status is "PAYING"
    And I am on the "P9a Ride payment" screen
    When the gateway reports that the payment failed
    Then I should not see "Rohan paid"
    And the "Continue" button should be disabled
    And I should see the action "Remind family"

  @negative
  Scenario: The app must not trust a paid status before the gateway webhook
    Given the payment request status is "PAYING"
    And I am on the "P9a Ride payment" screen
    When "Rohan Mehta" returns from the gateway but no webhook has confirmed the payment
    Then the "Continue" button should be disabled

  @negative
  Scenario: A double tap on Continue records one hospital arrival
    Given the payment request status is "PAID"
    And I am on the "P9a Ride payment" screen
    When I double tap "Continue"
    Then exactly one "Reached hospital" timeline event should exist for booking "PC-2481"
    And I should be on the "H1 Services to-do" screen

  @negative
  Scenario: Continue failure keeps the caretaker on P9a
    Given the payment request status is "PAID"
    And the reached hospital request will fail
    And I am on the "P9a Ride payment" screen
    When I tap "Continue"
    Then I should see an error
    And I should remain on the "P9a Ride payment" screen
    And the visit stage of booking "PC-2481" should be "RIDE_TO_HOSPITAL"

  # The design has no way forward if the family does not pay, and the patient is already at the hospital.
  @pending-design
  Scenario: The family does not pay for a long time
    Given the payment request status is "REQUESTED"
    And I have reminded the family
    When the family still does not pay
    Then the way for the caretaker to continue to the hospital should be confirmed by design

  # ---------- Remind family ----------

  @happy-path
  Scenario Outline: Reminding the family while the request is unpaid
    Given the payment request status is "<status>"
    And I am on the "P9a Ride payment" screen
    When I tap "Remind family"
    Then "Rohan Mehta" should receive a reminder for the "₹340" ride payment request
    And exactly one "RIDE_TO_HOSPITAL" payment request should exist for booking "PC-2481"
    And I should remain on the "P9a Ride payment" screen

    Examples:
      | status    |
      | REQUESTED |
      | FAILED    |

  @negative
  Scenario: Remind failure shows an error
    Given the payment request status is "REQUESTED"
    And the remind family request will fail
    And I am on the "P9a Ride payment" screen
    When I tap "Remind family"
    Then I should see an error
    And I should remain on the "P9a Ride payment" screen

  @pending-design
  Scenario: Remind family is rate limited
    Given I have just tapped "Remind family"
    When I tap "Remind family" again
    Then the cooldown should be confirmed by design

  @pending-design
  Scenario: Remind family after the family has paid
    Given the payment request status is "PAID"
    When I open the "P9a Ride payment" screen
    Then it should be confirmed by design whether "Remind family" is hidden

  # ---------- Navigation and resume ----------

  @ui-state @navigation
  Scenario: Payment made while the app was closed is shown on return
    Given the payment request status is "REQUESTED"
    And I am on the "P9a Ride payment" screen
    When I force close the Caretaker app
    And "Rohan Mehta" completes the payment on the gateway
    And I reopen the Caretaker app
    And I tap the resume arrow on the ongoing visit card
    And I continue to the fare request
    Then I should be on the "P9a Ride payment" screen
    And I should see "Rohan paid"
    And the "Continue" button should be enabled

  @navigation @negative
  Scenario: Back from P9a cannot create a second request
    Given I am on the "P9a Ride payment" screen
    When I press the device back button
    And I return to the "P9a Ride payment" screen
    Then exactly one "RIDE_TO_HOSPITAL" payment request should exist for booking "PC-2481"

  @navigation
  Scenario: Back from H1 does not return to P9a
    Given I reached the "H1 Services to-do" screen from the "P9a Ride payment" screen
    When I press the device back button
    Then I should not return to the "P9a Ride payment" screen
    And I should be on the "P1 Home" screen

  # ---------- Loading / error / offline ----------

  @ui-state
  Scenario: Skeleton while the payment status loads
    Given the ride payment request is slow to load
    When I open the "P9a Ride payment" screen
    Then I should see skeleton placeholders
    And the "Continue" button should be disabled

  @ui-state @negative
  Scenario: Error state with retry when the payment status fails to load
    Given the ride payment request fails to load
    When I open the "P9a Ride payment" screen
    Then I should see an error with a "Retry" button
    And the "Continue" button should be disabled

  @ui-state @negative @realtime
  Scenario: The latest payment status is fetched after reconnecting
    Given the payment request status is "REQUESTED"
    And I am on the "P9a Ride payment" screen
    And the device goes offline
    And "Rohan Mehta" completes the payment on the gateway
    When the device comes back online
    Then I should see "Rohan paid"
    And the "Continue" button should be enabled

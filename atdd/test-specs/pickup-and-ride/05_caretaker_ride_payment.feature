# Screen: P9a Ride payment (Caretaker app)
# Source: proxy-care-ui-ux-state-for-api-design.md (PRD v2.3) §5 P9a, §2 payment request status + visit stage, §7 realtime; PRD 3.2
# Back from H1 to P1 is covered in hospital-appointment/01_caretaker_services_todo.feature.
# The drop-off equivalent (D4a) belongs to the drop-off phase and is not covered here.
#
# Open design questions (no scenario until decided):
#   - How does the caretaker continue if the family never pays? Continue stays disabled and the patient is already at the hospital.
#   - Does "Remind family" have a cooldown, and is it hidden once paid?
#   - What does P9a show for a FAILED request? Scenarios only assert that "Rohan paid" is absent.

@regression @caretaker-app @pickup-and-ride @P9a @payments
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
    And I am logged in to the Caretaker app as "Anita Verma"
    And I am assigned to booking "PC-2481" for patient "Kamla Mehta"
    And the booking is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And the sponsoring user is "Rohan Mehta"
    And the ride has the driver "Sunil Yadav" and the latest event "TRIP_COMPLETED"
    And the booking has a "RIDE_TO_HOSPITAL" payment request for "₹340"

  # ---------- Display ----------

  @smoke @happy-path
  Scenario: P9a shows the fare and that the request was sent
    Given the ride payment request has status "REQUESTED"
    When I open the "P9a Ride payment" screen
    Then I should see the text "₹340"
    And I should see the text "Sunil Yadav"
    And I should see the text "Payment request sent to Rohan"
    And the "Remind family" button should be enabled
    And the "Continue" button should be disabled

  @ui-state
  Scenario Outline: Continue stays disabled until the request is paid
    Given the ride payment request has status "<status>"
    When I open the "P9a Ride payment" screen
    Then I should not see the text "Rohan paid"
    And the "Continue" button should be disabled

    Examples:
      | status    |
      | REQUESTED |
      | PAYING    |
      | FAILED    |

  @ui-state
  Scenario: A paid request enables Continue
    Given the ride payment request has status "PAID"
    When I open the "P9a Ride payment" screen
    Then I should see the text "Rohan paid"
    And the "Continue" button should be enabled

  @access-control @security
  Scenario: The caretaker has no way to pay and sees no payment details
    Given the ride payment request has status "PAID"
    When I open the "P9a Ride payment" screen
    Then I should not see any option to pay the fare myself
    And I should not see the card, UPI handle or bank of the payment
    And my earnings wallet balance should be unchanged

  # ---------- Family pays ----------

  @smoke @realtime
  Scenario: The screen updates when the family pays
    Given the ride payment request has status "REQUESTED"
    And I am on the "P9a Ride payment" screen
    When the gateway confirms the sponsoring user's payment
    Then I should see the text "Rohan paid" without a refresh
    And the "Continue" button should be enabled

  @smoke @happy-path
  Scenario: Continue opens the hospital services after payment
    Given the ride payment request has status "PAID"
    And I am on the "P9a Ride payment" screen
    When I tap "Continue"
    Then I should be on the "H1 Services to-do" screen
    And the booking should have stage "AT_HOSPITAL"
    And the booking should have 1 "Reached hospital" timeline event

  @negative @realtime
  Scenario: A failed family payment keeps Continue disabled
    Given the ride payment request has status "PAYING"
    And I am on the "P9a Ride payment" screen
    When the gateway reports the sponsoring user's payment as failed
    Then I should not see the text "Rohan paid"
    And the "Continue" button should be disabled
    And the "Remind family" button should be enabled

  @negative
  Scenario: A double tap on Continue records one hospital arrival
    Given the ride payment request has status "PAID"
    And I am on the "P9a Ride payment" screen
    When I double tap "Continue"
    Then the booking should have 1 "Reached hospital" timeline event
    And I should be on the "H1 Services to-do" screen

  @negative
  Scenario: A failed Continue keeps the caretaker on P9a
    Given the ride payment request has status "PAID"
    And the "reach hospital" request will fail
    And I am on the "P9a Ride payment" screen
    When I tap "Continue"
    Then I should see the "error" state
    And I should be on the "P9a Ride payment" screen
    And the booking should have stage "RIDE_TO_HOSPITAL"

  # ---------- Remind family ----------

  @happy-path
  Scenario Outline: Reminding the family while the request is unpaid
    Given the ride payment request has status "<status>"
    And I am on the "P9a Ride payment" screen
    When I tap "Remind family"
    Then the sponsoring user should get a reminder for the "₹340" ride payment request
    And the booking should have 1 "RIDE_TO_HOSPITAL" payment request for "₹340"
    And I should be on the "P9a Ride payment" screen

    Examples:
      | status    |
      | REQUESTED |
      | FAILED    |

  @negative
  Scenario: A failed reminder shows an error
    Given the ride payment request has status "REQUESTED"
    And the "remind family" request will fail
    And I am on the "P9a Ride payment" screen
    When I tap "Remind family"
    Then I should see the "error" state
    And I should be on the "P9a Ride payment" screen

  # ---------- Navigation and resume ----------

  @ui-state @device
  Scenario: A payment made while the app was closed is shown on return
    Given the ride payment request has status "PAID"
    And the app is closed
    When I reopen the app
    And I resume the ongoing visit
    And I open the existing fare request
    Then I should be on the "P9a Ride payment" screen
    And I should see the text "Rohan paid"
    And the "Continue" button should be enabled

  @navigation @device
  Scenario: Back from P9a keeps the single payment request
    Given the ride payment request has status "REQUESTED"
    And I am on the "P9a Ride payment" screen
    When I press the device back button
    Then the booking should have 1 "RIDE_TO_HOSPITAL" payment request for "₹340"

  # ---------- Loading / error / offline ----------

  @ui-state
  Scenario: Skeleton while the payment status loads
    Given the "ride payment request" request is slow
    When I open the "P9a Ride payment" screen
    Then I should see the "loading skeleton" state
    And the "Continue" button should be disabled

  @ui-state @negative
  Scenario: A failed load shows an error with Retry and blocks Continue
    Given the "ride payment request" request will fail
    When I open the "P9a Ride payment" screen
    Then I should see the "error" state
    And the "Retry" button should be enabled
    And the "Continue" button should be disabled

  @ui-state
  Scenario: Retry reloads the payment status
    Given the "ride payment request" request failed on the "P9a Ride payment" screen
    And the "ride payment request" request has recovered
    When I tap "Retry"
    Then I should see the text "₹340"

  @ui-state @negative
  Scenario: Going offline blocks the reminder and Continue
    Given the ride payment request has status "PAID"
    And I am on the "P9a Ride payment" screen
    When the device goes offline
    Then I should see the "offline banner" state
    And the "Remind family" button should be disabled
    And the "Continue" button should be disabled

  @ui-state @realtime
  Scenario: The latest payment status is fetched after reconnecting
    Given the ride payment request has status "REQUESTED"
    And I am on the "P9a Ride payment" screen
    And the device is offline
    And the gateway has confirmed the sponsoring user's payment
    When the device comes back online
    Then I should see the text "Rohan paid" without a refresh
    And the "Continue" button should be enabled

# Screen: B5 Finding caretaker - booking state WAITING (User app)
# Source: proxy-care-api-context.md (PRD v2.3) §4 B5, §2 booking state + cancellation policy, §6 realtime
# v2.3: shows "₹X paid" + receipt; cancellation refunds go to the bank / original payment method.
# Timeout / no-caretaker state is "not yet designed" (§8) - tagged @pending-design

@user-app @service-booking @B5
Feature: Finding a caretaker after payment
  As a User
  I want to see that my paid booking has been sent to nearby caretakers
  So that I know someone will be assigned, and I can cancel if plans change

  Background:
    Given today is "2026-10-31"
    And I am logged in to the User app as "Rohan Mehta"
    And I paid "₹1,249" through the gateway for booking "PC-2481" for "Kamla Mehta" with mobility "WHEELCHAIR"
    And the booking is for "2026-11-02" with pickup at "10:00 AM"
    And the booking state is "WAITING"
    And the booking was broadcast to 6 online, KYC-approved caretakers within 8 km

  # ---------- Display ----------

  @smoke
  Scenario: Waiting screen shows booking id, broadcast count, summary and payment
    When I am on the "B5 Finding caretaker" screen
    Then I should see the booking id "PC-2481"
    And I should see "Sent to 6 caretakers nearby"
    And I should see a searching animation
    And I should see the visit summary with patient, date, pickup time and hospital
    And I should see "₹1,249 paid" with a "Receipt" link
    And I should see the buttons "Back to home" and "Cancel booking"

  @happy-path
  Scenario: View payment receipt
    Given I am on the "B5 Finding caretaker" screen
    When I tap "Receipt"
    Then I should see the receipt with amount "₹1,249", booking "PC-2481", the payment time and the gateway reference

  # ---------- Realtime: caretaker accepts ----------

  @smoke @happy-path @realtime
  Scenario: Caretaker accepts while I'm on the waiting screen
    Given I am on the "B5 Finding caretaker" screen
    When caretaker "Anita Verma" accepts booking "PC-2481"
    Then I should see the banner "Anita Verma accepted your visit"
    And I should be taken to the "B6 Caretaker assigned" screen
    And the booking state should be "ASSIGNED"

  @realtime
  Scenario: Caretaker accepts while I'm on another screen
    Given I tapped "Back to home" from the "B5 Finding caretaker" screen
    When caretaker "Anita Verma" accepts booking "PC-2481"
    Then I should receive a push notification "Caretaker assigned for Kamla's visit"
    And the upcoming visit card for "PC-2481" should show "Caretaker assigned"
    When I tap the notification
    Then I should be on the "B6 Caretaker assigned" screen

  @realtime
  Scenario: App reopened after acceptance shows the assigned state
    Given the app was closed while booking "PC-2481" was "WAITING"
    And caretaker "Anita Verma" accepted the booking while the app was closed
    When I open booking "PC-2481"
    Then I should be on the "B6 Caretaker assigned" screen

  @realtime @error
  Scenario: Realtime connection drops and recovers
    Given I am on the "B5 Finding caretaker" screen
    And the realtime connection is lost
    And caretaker "Anita Verma" accepts booking "PC-2481" during the outage
    When the realtime connection is restored
    Then the screen should refresh the booking state
    And I should be taken to the "B6 Caretaker assigned" screen

  # ---------- Cancellation (refund to bank) ----------

  @happy-path
  Scenario Outline: Cancel booking shows the bank refund per policy
    Given the current time is "<now>"
    And I am on the "B5 Finding caretaker" screen
    When I tap "Cancel booking"
    Then a confirmation dialog should open
    And the dialog should show the refund "<refund>" and the deduction "<deduction>"
    And the dialog should say the refund goes to my bank account or original payment method
    When I tap "Yes, cancel booking"
    Then the booking state should be "CANCELLED"
    And a refund of "<refund>" should be created to my original payment method
    And I should see the toast "Booking cancelled. <refund> will be refunded to your bank"
    And I should be on the "B1 Home" screen
    And the upcoming visits should not include "PC-2481"

    Examples:
      | now              | refund | deduction |
      | 2026-10-31 19:50 | ₹1,150 | ₹99       |
      | 2026-11-02 01:59 | ₹1,150 | ₹99       |
      | 2026-11-02 02:01 | ₹400   | ₹849      |
      | 2026-11-02 09:30 | ₹400   | ₹849      |

  @negative
  Scenario: Dismissing the cancel dialog keeps the booking
    Given I am on the "B5 Finding caretaker" screen
    When I tap "Cancel booking"
    And I tap "Keep booking"
    Then the dialog should close
    And the booking state should be "WAITING"
    And no refund should be created

  @realtime @negative
  Scenario: Caretaker accepts while the cancel dialog is open
    Given I am on the "B5 Finding caretaker" screen
    And I have opened the cancel booking dialog
    When caretaker "Anita Verma" accepts booking "PC-2481"
    Then the cancel dialog should update to show that a caretaker has been assigned
    And the refund amount should still follow the cancellation policy

  @realtime
  Scenario: Cancelling withdraws the request from caretakers
    Given caretakers have open requests for booking "PC-2481"
    When I cancel booking "PC-2481"
    Then every open request for "PC-2481" in the caretaker app should show "Request cancelled by family"
    And no caretaker should be able to accept "PC-2481"

  @error
  Scenario: Cancel fails and the booking stays active
    Given I am on the "B5 Finding caretaker" screen
    And the cancel API returns a server error
    When I tap "Cancel booking"
    And I tap "Yes, cancel booking"
    Then I should see the error "Couldn't cancel. Please try again."
    And the booking state should be "WAITING"
    And no refund should be created

  @ui-state
  Scenario: Cancel confirmation shows processing and prevents double submit
    Given I am on the "B5 Finding caretaker" screen
    And the cancel API responds slowly
    When I tap "Cancel booking"
    And I tap "Yes, cancel booking"
    Then the "Yes, cancel booking" button should show a spinner and be disabled
    And only one cancel request should be sent
    And only one refund should be created

  # ---------- Navigation ----------

  @navigation
  Scenario: Back to home keeps the booking active
    Given I am on the "B5 Finding caretaker" screen
    When I tap "Back to home"
    Then I should be on the "B1 Home" screen
    And the upcoming visits should show "PC-2481" with status "Finding caretaker"

  @navigation
  Scenario: Device back from B5 goes Home, not back to payment
    Given I am on the "B5 Finding caretaker" screen
    When I press the device back button
    Then I should be on the "B1 Home" screen
    And I should not be able to navigate back to the "B4 Review · Confirm & Pay" screen for "PC-2481"

  # ---------- Not yet designed ----------

  @pending-design
  Scenario: No caretaker accepts before the request times out
    Given no caretaker has accepted booking "PC-2481"
    When the dispatch window expires
    Then I should see a "No caretaker found" state
    And I should be offered to retry the search or cancel with a full refund to my bank

  @pending-design
  Scenario: No online caretakers nearby at booking time
    Given there are 0 online caretakers within 8 km of the patient
    When my payment for a new booking is confirmed
    Then I should see that no caretaker is available right now

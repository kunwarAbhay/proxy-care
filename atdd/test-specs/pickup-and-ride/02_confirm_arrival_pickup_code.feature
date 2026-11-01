# Screen: P5 Confirm arrival (Caretaker app)
# Source: proxy-care-ui-ux-state-for-api-design.md (PRD v2.3) §5 P5, §1 Patient + Booking, §2 booking state + visit stage + fee strategy, §7 realtime; PRD 3.2
# The design names the "wrong code" and "too many attempts" states but gives neither the wording nor the attempt limit.
# These scenarios therefore refer to the states by name and read the limit from configuration.

@caretaker-app @pickup-and-ride @P5
Feature: Caretaker confirms arrival with the pickup code
  As an assigned Caretaker at the patient's home
  I want to enter the 4-digit pickup code from the family
  So that the handover is verified and the visit officially starts

  Rules (context §1, §2, §5):
    - The code has 4 digits. The sponsor sees it in the User app and the patient receives it by SMS.
    - The caretaker never sees the code; it is only checked on the server.
    - A correct code moves the booking ASSIGNED -> IN_PROGRESS, sets stage PICKED_UP and starts billable time.
    - The patient's mobile is optional.

  Background:
    Given today is "2026-11-02"
    And I am logged in to the Caretaker app as "Anita Verma" with KYC "APPROVED"
    And I am assigned to booking "PC-2481" for patient "Kamla Mehta"
    And booking "PC-2481" is in state "ASSIGNED" with stage "HEADING_TO_PICKUP"
    And the sponsoring user is "Rohan Mehta", relation "Son"
    And the pickup code for "PC-2481" is "4821"

  # ---------- Display ----------

  @smoke
  Scenario: P5 asks for the code without revealing it
    When I open the "P5 Confirm arrival" screen
    Then I should see an empty 4-digit "Pickup code" field marked as required
    And the "Confirm arrival" button should be disabled
    And I should see the actions "Call family" and "Resend code"
    And I should not see the pickup code

  # ---------- Happy path ----------

  @smoke @happy-path
  Scenario: Correct code starts the visit
    Given I am on the "P5 Confirm arrival" screen
    When I enter "4821" in the "Pickup code" field
    And I tap "Confirm arrival"
    Then booking "PC-2481" should be in state "IN_PROGRESS"
    And the visit stage of booking "PC-2481" should be "PICKED_UP"
    And billable time should start at the verification time
    And I should be on the "P6 Book ride or skip" screen
    And "Rohan Mehta" should receive a "Pickup OTP verified" timeline event
    And the ongoing visit card on "Rohan Mehta"'s Home should show the stage badge "Patient picked up"

  @ui-state
  Scenario: Confirm arrival shows progress while the code is checked
    Given the pickup code verification is slow
    And I am on the "P5 Confirm arrival" screen
    When I enter "4821" in the "Pickup code" field
    And I tap "Confirm arrival"
    Then the "Confirm arrival" button should show a loader and be disabled

  # ---------- Input validation ----------

  @negative
  Scenario Outline: Confirm arrival is enabled only for a complete 4-digit code
    Given I am on the "P5 Confirm arrival" screen
    When I enter "<input>" in the "Pickup code" field
    Then the "Pickup code" field should contain "<shown>"
    And the "Confirm arrival" button should be <state>

    Examples:
      | input | shown | state    |
      | 4     | 4     | disabled |
      | 48    | 48    | disabled |
      | 482   | 482   | disabled |
      | 4821  | 4821  | enabled  |
      | 48215 | 4821  | enabled  |
      | abcd  |       | disabled |
      | 48a1  | 481   | disabled |
      | 48-1  | 481   | disabled |

  Scenario: Deleting a digit disables Confirm arrival again
    Given I am on the "P5 Confirm arrival" screen
    And I have entered "4821" in the "Pickup code" field
    When I delete the last digit
    Then the "Confirm arrival" button should be disabled

  @negative
  Scenario Outline: Wrong code does not start the visit
    Given I am on the "P5 Confirm arrival" screen
    When I enter "<code>" in the "Pickup code" field
    And I tap "Confirm arrival"
    Then I should see the "wrong code" state
    And I should remain on the "P5 Confirm arrival" screen
    And booking "PC-2481" should still be in state "ASSIGNED"
    And billable time should not have started
    And "Rohan Mehta" should not receive a "Pickup OTP verified" timeline event

    Examples:
      | code |
      | 1234 |
      | 0000 |
      | 1284 |
      | 4822 |

  @negative @security
  Scenario: The code of another booking is not accepted
    Given booking "PC-2490" has the pickup code "9173"
    And I am on the "P5 Confirm arrival" screen for booking "PC-2481"
    When I enter "9173" in the "Pickup code" field
    And I tap "Confirm arrival"
    Then I should see the "wrong code" state
    And booking "PC-2481" should still be in state "ASSIGNED"

  @negative
  Scenario: The right code is accepted after a wrong attempt
    Given I am on the "P5 Confirm arrival" screen
    And I entered the wrong code "1234" once
    When I replace the code with "4821"
    And I tap "Confirm arrival"
    Then booking "PC-2481" should be in state "IN_PROGRESS"
    And I should be on the "P6 Book ride or skip" screen

  # ---------- Too many attempts ----------

  @negative @security
  Scenario: Reaching the attempt limit blocks further attempts
    Given I am on the "P5 Confirm arrival" screen
    When I enter a wrong code as many times as the configured attempt limit
    Then I should see the "too many attempts" state
    And the "Confirm arrival" button should be disabled
    And the "Call family" action should stay available
    And booking "PC-2481" should still be in state "ASSIGNED"

  @negative @security @api
  Scenario: The correct code is rejected while attempts are blocked
    Given the pickup code attempts for booking "PC-2481" are blocked
    When the app submits the code "4821" for booking "PC-2481"
    Then the server should reject the request
    And booking "PC-2481" should still be in state "ASSIGNED"
    And billable time should not have started

  @ui-state @security
  Scenario: Reopening the app does not clear the attempt block
    Given the pickup code attempts for booking "PC-2481" are blocked
    When I force close and reopen the Caretaker app
    And I open the "P5 Confirm arrival" screen
    Then I should see the "too many attempts" state

  # The design gives no attempt limit, block duration or way to recover.
  @pending-design
  Scenario: Recovering from too many attempts
    Given the pickup code attempts for booking "PC-2481" are blocked
    Then the attempt limit, block duration and recovery path should be confirmed by design

  # ---------- Resend code ----------

  @happy-path
  Scenario: Resend code sends the current code to the patient
    Given the patient "Kamla Mehta" has mobile "+919812345678"
    And I am on the "P5 Confirm arrival" screen
    When I tap "Resend code"
    Then an SMS with the pickup code should be sent to "+919812345678"
    And the code in that SMS should match the code shown to "Rohan Mehta"
    And I should remain on the "P5 Confirm arrival" screen
    And I should not see the pickup code

  @negative
  Scenario: Resend failure keeps the caretaker on the screen
    Given the resend code request will fail
    And I am on the "P5 Confirm arrival" screen
    When I tap "Resend code"
    Then I should see an error
    And I should remain on the "P5 Confirm arrival" screen

  @happy-path
  Scenario: A patient without a mobile can still be picked up with the sponsor's code
    Given the patient "Kamla Mehta" has no mobile
    And "Rohan Mehta" can see the pickup code "4821" in the User app
    And I am on the "P5 Confirm arrival" screen
    When I enter "4821" in the "Pickup code" field
    And I tap "Confirm arrival"
    Then booking "PC-2481" should be in state "IN_PROGRESS"

  @pending-design
  Scenario: Resend code when the patient has no mobile
    Given the patient "Kamla Mehta" has no mobile
    When I tap "Resend code"
    Then the expected behaviour should be confirmed by design

  @pending-design
  Scenario: Resend code is rate limited
    Given I have just tapped "Resend code"
    When I tap "Resend code" again
    Then the cooldown and resend limit should be confirmed by design

  # ---------- Actions ----------

  @happy-path
  Scenario: Call family opens the dialer so the caretaker can ask for the code
    Given I am on the "P5 Confirm arrival" screen
    When I tap "Call family"
    Then the phone dialer should open with the number of "Rohan Mehta"

  # ---------- Resilience ----------

  @negative
  Scenario: A double tap verifies the code once
    Given I am on the "P5 Confirm arrival" screen
    And I have entered "4821" in the "Pickup code" field
    When I double tap "Confirm arrival"
    Then exactly one verification request should be sent
    And I should be on the "P6 Book ride or skip" screen

  @ui-state @negative
  Scenario: Network failure keeps the entered code and allows a retry
    Given the pickup code verification will fail with a network error
    And I am on the "P5 Confirm arrival" screen
    When I enter "4821" in the "Pickup code" field
    And I tap "Confirm arrival"
    Then I should see an error
    And the "Pickup code" field should contain "4821"
    And the "Confirm arrival" button should be enabled
    And the failed request should not count as a wrong attempt
    And booking "PC-2481" should still be in state "ASSIGNED"

  @negative @api
  Scenario: Retrying after a lost response keeps the original start time
    Given my code "4821" was verified at "09:58 AM" but the response was lost
    When the app submits the code "4821" again at "09:59 AM"
    Then the app should move to the "P6 Book ride or skip" screen
    And billable time should still start at "09:58 AM"
    And "Rohan Mehta" should have only one "Pickup OTP verified" timeline event

  @ui-state @negative
  Scenario: Offline banner blocks confirmation
    Given I am on the "P5 Confirm arrival" screen
    And I have entered "4821" in the "Pickup code" field
    When the device goes offline
    Then I should see an offline banner
    And the "Confirm arrival" button should be disabled

  # ---------- Navigation ----------

  @navigation
  Scenario: Back from P5 before verification returns to P4
    Given I am on the "P5 Confirm arrival" screen
    When I press the device back button
    Then I should be on the "P4 Start trip to pickup" screen
    And booking "PC-2481" should still be in state "ASSIGNED"

  @navigation
  Scenario: A verified code cannot be revisited with back
    Given my pickup code was verified
    And I am on the "P6 Book ride or skip" screen
    When I press the device back button
    Then I should not return to the "P5 Confirm arrival" screen
    And booking "PC-2481" should still be in state "IN_PROGRESS"

  @navigation @ui-state
  Scenario: Reopening the app before verification resumes at P4
    Given I am on the "P5 Confirm arrival" screen
    And I have entered "48" in the "Pickup code" field
    When I force close and reopen the Caretaker app
    And I tap the resume arrow on the ongoing visit card
    Then I should be on the "P4 Start trip to pickup" screen

  @navigation @ui-state
  Scenario: Reopening the app after verification resumes at P6
    Given my pickup code was verified
    When I force close and reopen the Caretaker app
    Then the ongoing visit card should show the stage badge "Patient picked up"
    When I tap the resume arrow on the ongoing visit card
    Then I should be on the "P6 Book ride or skip" screen

# Screen: P4 Start trip to pickup (Caretaker app)
# Source: proxy-care-ui-ux-state-for-api-design.md (PRD v2.3) §5 P4, §2 visit stage + location visibility, §8 common UI states; PRD 3.3
# The "Start trip to pickup" card button on P3 is covered in service-booking/10_caretaker_home_and_visits.feature.
#
# Open design questions (no scenario until decided):
#   - Is HEADING_TO_PICKUP set on opening P4 or on turning the toggle on? Scenarios only assert it once the toggle is on.
#   - Can the toggle be turned off before drop-off, and what happens to sharing if it is?
#   - Can the caretaker tap "I've arrived" with the toggle off?
#   - What does a deep link to P4 do before the visit day?

@regression @caretaker-app @pickup-and-ride @P4
Feature: Caretaker starts the trip to the patient's home
  As an assigned Caretaker
  I want to see the route to the patient's home and share my live location
  So that I reach the pickup on time and the family can follow my trip

  Rules (context §2, §5, PRD 3.3):
    - Live location sharing starts when the caretaker turns on "Reaching pickup location" and ends at drop-off.
    - The caretaker sees their own live location and the patient's home address, never a patient live location.
    - The user sees the caretaker's live location. The patient sees no location at all.
    - Resume target for stage HEADING_TO_PICKUP is P4.

  Background:
    Given today is "2026-11-02"
    And I am logged in to the Caretaker app as "Anita Verma"
    And I am assigned to booking "PC-2481" for patient "Kamla Mehta" with mobility "WHEELCHAIR"
    And the booking is in state "ASSIGNED"
    And the patient's home address is "B-14, Malviya Nagar, New Delhi"
    And the sponsoring user is "Rohan Mehta"

  # ---------- Display ----------

  @smoke @happy-path
  Scenario: P4 shows the route, the patient and the actions
    When I open the "P4 Start trip to pickup" screen
    Then I should see the map with my own location and the patient's home
    And I should see the ETA and distance to the patient's home
    And I should see the text "Kamla Mehta"
    And I should see the text "Wheelchair"
    And I should see the text "B-14, Malviya Nagar, New Delhi"
    And the "Reaching pickup location" toggle should be off
    And the "Call family" button should be enabled
    And the "I've arrived" button should be enabled

  @access-control @security
  Scenario: P4 never shows the pickup code or a patient live location
    When I open the "P4 Start trip to pickup" screen
    Then I should not see the pickup code
    And the map should not show a patient live location

  # ---------- Reaching pickup location toggle ----------

  @smoke @happy-path
  Scenario: Turning on the toggle starts live location sharing
    Given I am on the "P4 Start trip to pickup" screen
    When I turn on the "Reaching pickup location" toggle
    Then live location sharing should be active
    And the booking should have stage "HEADING_TO_PICKUP"
    And the sponsoring user should see the caretaker pin on the "U1 Caretaker live location" screen
    And the sponsoring user should see the stage badge "Heading to pickup"

  @negative
  Scenario: No location is sent while the toggle is off
    Given I am on the "P4 Start trip to pickup" screen
    When my device location changes
    Then no location update should be sent

  @negative
  Scenario: The toggle returns to off when sharing cannot start
    Given the "start location sharing" request will fail
    And I am on the "P4 Start trip to pickup" screen
    When I turn on the "Reaching pickup location" toggle
    Then the "Reaching pickup location" toggle should be off
    And I should see the "error" state
    And live location sharing should be inactive

  @access-control @security @integration
  Scenario: The patient receives no location telemetry when sharing starts
    Given the patient has mobile "+919812345678"
    And I am on the "P4 Start trip to pickup" screen
    When I turn on the "Reaching pickup location" toggle
    Then no location link should be sent to "+919812345678"

  @negative @pending-design @device
  Scenario: Sharing does not start when location permission is denied
    Given location permission is denied for the app
    And I am on the "P4 Start trip to pickup" screen
    When I turn on the "Reaching pickup location" toggle
    Then the "Reaching pickup location" toggle should be off
    And live location sharing should be inactive

  # ---------- Actions ----------

  @happy-path @device
  Scenario: Call family opens the dialer
    Given I am on the "P4 Start trip to pickup" screen
    When I tap "Call family"
    Then the phone dialer should open with the number of "Rohan Mehta"

  @smoke @navigation
  Scenario: I've arrived opens the code confirmation without starting the visit
    Given live location sharing is active
    And I am on the "P4 Start trip to pickup" screen
    When I tap "I've arrived"
    Then I should be on the "P5 Confirm arrival" screen
    And the booking should be in state "ASSIGNED"
    And live location sharing should be active

  # ---------- Navigation and resume ----------

  @navigation
  Scenario: The resume arrow opens P4 for stage HEADING_TO_PICKUP
    Given the booking has stage "HEADING_TO_PICKUP"
    And I am on the "P1 Home" screen
    When I resume the ongoing visit
    Then I should be on the "P4 Start trip to pickup" screen

  @navigation @device
  Scenario Outline: Back from P4 returns to where it was opened and keeps sharing
    Given live location sharing is active
    And I opened the "P4 Start trip to pickup" screen from the "<origin>" screen
    When I press the device back button
    Then I should be on the "<origin>" screen
    And live location sharing should be active

    Examples:
      | origin       |
      | P3 My visits |
      | P1 Home      |

  @ui-state @device
  Scenario: Sharing survives the app being killed and reopened
    Given live location sharing is active
    And the booking has stage "HEADING_TO_PICKUP"
    When I force close and reopen the app
    And I resume the ongoing visit
    Then I should be on the "P4 Start trip to pickup" screen
    And the "Reaching pickup location" toggle should be on

  # ---------- Loading / error / offline ----------

  @ui-state
  Scenario: Skeleton while the trip details load
    Given the "visit details" request is slow
    When I open the "P4 Start trip to pickup" screen
    Then I should see the "loading skeleton" state
    And the "I've arrived" button should be disabled

  @ui-state @negative
  Scenario: A failed load shows an error with Retry
    Given the "visit details" request will fail
    When I open the "P4 Start trip to pickup" screen
    Then I should see the "error" state
    And the "Retry" button should be enabled

  @ui-state
  Scenario: Retry reloads the trip details
    Given the "visit details" request failed on the "P4 Start trip to pickup" screen
    And the "visit details" request has recovered
    When I tap "Retry"
    Then I should see the text "B-14, Malviya Nagar, New Delhi"

  @ui-state @negative
  Scenario: Going offline blocks the actions that need the server
    Given I am on the "P4 Start trip to pickup" screen
    When the device goes offline
    Then I should see the "offline banner" state
    And the "Reaching pickup location" toggle should be disabled
    And the "I've arrived" button should be disabled

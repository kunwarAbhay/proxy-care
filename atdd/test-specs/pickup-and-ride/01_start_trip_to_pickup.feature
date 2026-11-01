# Screen: P4 Start trip to pickup (Caretaker app)
# Source: proxy-care-ui-ux-state-for-api-design.md (PRD v2.3) §5 P4, §2 visit stage + location visibility, §8 common UI states; PRD 3.3
# The "Start trip to pickup" card button on P3 is covered in service-booking/10_caretaker_home_and_visits.feature.
# The design does not say whether HEADING_TO_PICKUP is set on opening P4 or on turning the toggle on,
# so these scenarios only assert the stage once the toggle is on.

@caretaker-app @pickup-and-ride @P4
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
    And I am logged in to the Caretaker app as "Anita Verma" with KYC "APPROVED"
    And I am assigned to booking "PC-2481" for patient "Kamla Mehta", 68, with mobility "WHEELCHAIR"
    And booking "PC-2481" is in state "ASSIGNED" with pickup at "10:00 AM"
    And the patient's home address is "B-14, Malviya Nagar, New Delhi"
    And the sponsoring user is "Rohan Mehta", relation "Son"

  # ---------- Display ----------

  @smoke
  Scenario: P4 shows the route, the patient and the actions
    When I open the "P4 Start trip to pickup" screen
    Then I should see a map with my own location and the patient's home
    And I should see the ETA and distance to the patient's home
    And I should see the patient "Kamla Mehta" with the mobility "Wheelchair"
    And I should see the address "B-14, Malviya Nagar, New Delhi"
    And I should see the "Reaching pickup location" toggle turned off
    And I should see the actions "Call family" and "I've arrived"

  @access-control @security
  Scenario: P4 never shows the pickup code or a patient live location
    When I open the "P4 Start trip to pickup" screen
    Then I should not see the pickup code
    And the map should show the patient's home as a fixed address pin
    And the map should not show a patient live location

  # ---------- Reaching pickup location toggle ----------

  @smoke @happy-path
  Scenario: Turning on the toggle starts live location sharing
    Given I am on the "P4 Start trip to pickup" screen
    When I turn on the "Reaching pickup location" toggle
    Then live location sharing should start for booking "PC-2481"
    And the visit stage of booking "PC-2481" should be "HEADING_TO_PICKUP"
    And "Rohan Mehta" should start receiving my location updates
    And the ongoing visit card on "Rohan Mehta"'s Home should show the stage badge "Heading to pickup"

  @negative
  Scenario: No location is shared while the toggle is off
    Given I am on the "P4 Start trip to pickup" screen
    And the "Reaching pickup location" toggle is off
    When my device location changes
    Then no location update should be sent for booking "PC-2481"

  @negative
  Scenario: Toggle returns to off when sharing cannot be started
    Given the request to start location sharing will fail
    And I am on the "P4 Start trip to pickup" screen
    When I turn on the "Reaching pickup location" toggle
    Then the "Reaching pickup location" toggle should return to off
    And I should see an error
    And live location sharing should not be active for booking "PC-2481"

  @access-control @security
  Scenario: The patient receives no location telemetry when sharing starts
    Given the patient "Kamla Mehta" has mobile "+919812345678"
    And I am on the "P4 Start trip to pickup" screen
    When I turn on the "Reaching pickup location" toggle
    Then no location link or location update should be sent to "+919812345678"

  # The design does not define these location cases.
  @pending-design
  Scenario: Location permission is denied
    Given location permission is denied for the Caretaker app
    When I turn on the "Reaching pickup location" toggle
    Then the toggle should stay off
    And I should be told that location access is needed

  @pending-design
  Scenario: The caretaker turns the toggle off before drop-off
    Given live location sharing is active for booking "PC-2481"
    When I turn off the "Reaching pickup location" toggle
    Then the expected sharing behaviour should be confirmed by design

  @pending-design
  Scenario: Arriving without having turned on the toggle
    Given the "Reaching pickup location" toggle is off
    When I tap "I've arrived"
    Then the expected behaviour should be confirmed by design

  # ---------- Actions ----------

  @happy-path
  Scenario: Call family opens the dialer
    Given I am on the "P4 Start trip to pickup" screen
    When I tap "Call family"
    Then the phone dialer should open with the number of "Rohan Mehta"

  @smoke @navigation
  Scenario: I've arrived opens the code confirmation
    Given live location sharing is active for booking "PC-2481"
    And I am on the "P4 Start trip to pickup" screen
    When I tap "I've arrived"
    Then I should be on the "P5 Confirm arrival" screen
    And booking "PC-2481" should still be in state "ASSIGNED"
    And live location sharing should still be active

  # ---------- Navigation and resume ----------

  @navigation
  Scenario: Resume arrow on Home opens P4 for stage HEADING_TO_PICKUP
    Given booking "PC-2481" has stage "HEADING_TO_PICKUP"
    And I am on the "P1 Home" screen
    Then the ongoing visit card should show the stage badge "Heading to pickup"
    When I tap the resume arrow on the ongoing visit card
    Then I should be on the "P4 Start trip to pickup" screen

  @navigation
  Scenario Outline: Back from P4 returns to where it was opened and keeps sharing
    Given I opened the "P4 Start trip to pickup" screen from the "<origin>" screen
    And live location sharing is active for booking "PC-2481"
    When I press the device back button
    Then I should be on the "<origin>" screen
    And live location sharing should still be active

    Examples:
      | origin       |
      | P3 My visits |
      | P1 Home      |

  @ui-state
  Scenario: Sharing survives the app being killed and reopened
    Given live location sharing is active for booking "PC-2481"
    And booking "PC-2481" has stage "HEADING_TO_PICKUP"
    When I force close and reopen the Caretaker app
    And I tap the resume arrow on the ongoing visit card
    Then I should be on the "P4 Start trip to pickup" screen
    And the "Reaching pickup location" toggle should be on

  # ---------- Loading / error / offline ----------

  @ui-state
  Scenario: Skeleton while the trip details load
    Given the visit details request is slow
    When I open the "P4 Start trip to pickup" screen
    Then I should see skeleton placeholders
    And the "I've arrived" action should be disabled

  @ui-state @negative
  Scenario: Error state with retry when the trip details fail to load
    Given the visit details request fails
    When I open the "P4 Start trip to pickup" screen
    Then I should see an error with a "Retry" button
    When the visit details request succeeds
    And I tap "Retry"
    Then I should see the patient "Kamla Mehta" and the address "B-14, Malviya Nagar, New Delhi"

  @pending-design
  Scenario: The trip is opened by deep link before the visit day
    Given today is "2026-11-01"
    When I open a deep link to the "P4 Start trip to pickup" screen for booking "PC-2481"
    Then live location sharing should not be active for booking "PC-2481"

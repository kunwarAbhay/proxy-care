# Screen: P4 Start trip to pickup, and the live location lifecycle (Caretaker app)
# Source: proxy-care-ui-ux-state-for-api-design.md (PRD v2.3) §5 P3/P4, §2 visit stage + location visibility, §8 common UI states; PRD 3.3
# Product decision (3 Nov 2026), overriding §2, §5 P4 and PRD 3.3:
#   - The only caretaker availability toggle is online/offline on P1. It only controls whether visit requests are received.
#   - P4 has no "Reaching pickup location" toggle.
#   - Location broadcasting starts when the trip to pickup starts and stops when the visit is marked completed on D5.
# Assumption: "Start trip to pickup" on P3 sets stage HEADING_TO_PICKUP, as it is the action that starts the trip.
# Assumption: "addresses" on P4 means the patient's home and the hospital.
# The P3 card rules for "Start trip to pickup" are covered in service-booking/10_caretaker_home_and_visits.feature.
#
# Open design questions (no scenario until decided):
#   - If location permission is denied, can the trip still continue on P4?
#   - What does the P1 ongoing visit card show for an ASSIGNED booking before the trip starts, when there is no stage yet?
#   - What does a deep link to P4 do before the visit day?

@regression @caretaker-app @pickup-and-ride @P3 @P4
Feature: Caretaker starts the trip to the patient's home
  As an assigned Caretaker
  I want to start my trip and see the route to the patient's home
  So that I reach the pickup on time and the family can follow my trip

  Rules (product decision, context §2, §5, PRD 3.3):
    - Starting the trip to pickup starts live location broadcasting. Marking the visit completed stops it.
    - The online/offline toggle on P1 only controls visit requests and has no effect on location.
    - The caretaker sees their own live location and the patient's home address, never a patient live location.
    - The user sees the caretaker's live location. The patient sees no location at all.
    - Resume target for stage HEADING_TO_PICKUP is P4.

  Background:
    Given today is "2026-11-02"
    And I am logged in to the Caretaker app as "Anita Verma"
    And I am assigned to booking "PC-2481" for patient "Kamla Mehta" with mobility "WHEELCHAIR"
    And the booking is in state "ASSIGNED"
    And the patient's home address is "B-14, Malviya Nagar, New Delhi"
    And the hospital is "Max Super Speciality Hospital, Saket"
    And the sponsoring user is "Rohan Mehta"

  # ---------- Starting the trip ----------

  @smoke @happy-path
  Scenario: Starting the trip starts broadcasting and opens P4
    Given I am on the "P3 My visits" screen
    When I tap "Start trip to pickup"
    Then I should be on the "P4 Start trip to pickup" screen
    And the booking should have stage "HEADING_TO_PICKUP"
    And live location sharing should be active
    And the sponsoring user should see the caretaker pin on the "U1 Caretaker live location" screen
    And the sponsoring user should see the stage badge "Heading to pickup"

  @negative
  Scenario: No location is sent before the trip starts
    Given I am on the "P3 My visits" screen
    When my device location changes
    Then no location update should be sent
    And live location sharing should be inactive

  @negative
  Scenario: A failed start keeps the caretaker on P3 without broadcasting
    Given the "start trip to pickup" request will fail
    And I am on the "P3 My visits" screen
    When I tap "Start trip to pickup"
    Then I should see the "error" state
    And I should be on the "P3 My visits" screen
    And the booking should have no stage
    And live location sharing should be inactive

  @negative
  Scenario: A double tap starts the trip once
    Given I am on the "P3 My visits" screen
    When I double tap "Start trip to pickup"
    Then exactly 1 "start trip to pickup" request should be sent
    And I should be on the "P4 Start trip to pickup" screen

  @ui-state @negative
  Scenario: Going offline blocks starting the trip
    Given I am on the "P3 My visits" screen
    When the device goes offline
    Then I should see the "offline banner" state
    And the "Start trip to pickup" button should be disabled

  @access-control @security @integration
  Scenario: The patient receives no location telemetry when the trip starts
    Given the patient has mobile "+919812345678"
    And I am on the "P3 My visits" screen
    When I tap "Start trip to pickup"
    Then no location link should be sent to "+919812345678"

  @negative @pending-design @device
  Scenario: Nothing is broadcast when location permission is denied
    Given location permission is denied for the app
    And I am on the "P3 My visits" screen
    When I tap "Start trip to pickup"
    Then live location sharing should be inactive

  # ---------- P4 display ----------

  @smoke @happy-path
  Scenario: P4 shows the route, the patient and the actions
    Given the trip to pickup has started
    When I open the "P4 Start trip to pickup" screen
    Then I should see the map with my own location and the patient's home
    And I should see the ETA and distance to the patient's home
    And I should see the text "Kamla Mehta"
    And I should see the text "Wheelchair"
    And I should see the text "B-14, Malviya Nagar, New Delhi"
    And I should see the text "Max Super Speciality Hospital, Saket"
    And the "Call family" button should be enabled
    And the "I've arrived" button should be enabled

  @ui-validation
  Scenario: P4 has no location toggle
    Given the trip to pickup has started
    When I open the "P4 Start trip to pickup" screen
    Then I should not see the "Reaching pickup location" toggle

  @access-control @security
  Scenario: P4 never shows the pickup code or a patient live location
    Given the trip to pickup has started
    When I open the "P4 Start trip to pickup" screen
    Then I should not see the pickup code
    And the map should not show a patient live location

  # ---------- Online/offline toggle is independent of location ----------

  @negative
  Scenario: Going offline during a visit does not stop broadcasting
    Given the trip to pickup has started
    And I am on the "P1 Home" screen
    When I toggle offline on the "P1 Home" screen
    Then live location sharing should be active

  @negative
  Scenario: Going online does not start broadcasting
    Given I am offline on the "P1 Home" screen
    When I toggle online on the "P1 Home" screen
    Then live location sharing should be inactive
    And no location update should be sent

  # ---------- Broadcasting lifecycle ----------

  @happy-path
  Scenario Outline: Broadcasting continues through every stage until the visit is completed
    Given the trip to pickup has started
    And the booking is in state "IN_PROGRESS"
    When the booking moves to stage "<stage>"
    Then live location sharing should be active

    Examples: Pickup and ride
      | stage                     |
      | PICKED_UP                 |
      | RIDE_TO_HOSPITAL          |
      | OWN_TRANSPORT_TO_HOSPITAL |
      | AT_HOSPITAL               |

    Examples: Drop-off
      | stage              |
      | RIDE_HOME          |
      | OWN_TRANSPORT_HOME |
      | HANDOVER           |

  @negative
  Scenario: Completing the hospital services does not stop broadcasting
    Given the booking is in state "IN_PROGRESS" with stage "AT_HOSPITAL"
    And live location sharing is active
    And one hospital service is still not completed
    When I complete the last hospital service
    Then live location sharing should be active

  @smoke @happy-path
  Scenario: Marking the visit completed stops broadcasting
    Given the booking is in state "IN_PROGRESS" with stage "HANDOVER"
    And live location sharing is active
    And I am on the "D5 Handover & Visit Completed" screen
    When I mark the visit completed
    Then the booking should be in state "COMPLETED"
    And live location sharing should be inactive

  # ---------- Actions ----------

  @happy-path @device
  Scenario: Call family opens the dialer
    Given the trip to pickup has started
    And I am on the "P4 Start trip to pickup" screen
    When I tap "Call family"
    Then the phone dialer should open with the number of "Rohan Mehta"

  @smoke @navigation
  Scenario: I've arrived opens the code confirmation without starting the visit
    Given the trip to pickup has started
    And I am on the "P4 Start trip to pickup" screen
    When I tap "I've arrived"
    Then I should be on the "P5 Confirm arrival" screen
    And the booking should be in state "ASSIGNED"
    And live location sharing should be active

  # ---------- Navigation and resume ----------

  @navigation
  Scenario: The resume arrow opens P4 for stage HEADING_TO_PICKUP
    Given the trip to pickup has started
    And I am on the "P1 Home" screen
    When I resume the ongoing visit
    Then I should be on the "P4 Start trip to pickup" screen
    And exactly 0 "start trip to pickup" requests should be sent

  @navigation @device
  Scenario Outline: Back from P4 returns to where it was opened and keeps broadcasting
    Given the trip to pickup has started
    And I opened the "P4 Start trip to pickup" screen from the "<origin>" screen
    When I press the device back button
    Then I should be on the "<origin>" screen
    And live location sharing should be active

    Examples:
      | origin       |
      | P3 My visits |
      | P1 Home      |

  @ui-state @device
  Scenario: Broadcasting survives the app being killed and reopened
    Given the trip to pickup has started
    When I force close and reopen the app
    And I resume the ongoing visit
    Then I should be on the "P4 Start trip to pickup" screen
    And live location sharing should be active

  # ---------- Loading / error / offline ----------

  @ui-state
  Scenario: Skeleton while the trip details load
    Given the trip to pickup has started
    And the "visit details" request is slow
    When I open the "P4 Start trip to pickup" screen
    Then I should see the "loading skeleton" state
    And the "I've arrived" button should be disabled

  @ui-state @negative
  Scenario: A failed load shows an error with Retry
    Given the trip to pickup has started
    And the "visit details" request will fail
    When I open the "P4 Start trip to pickup" screen
    Then I should see the "error" state
    And the "Retry" button should be enabled

  @ui-state
  Scenario: Retry reloads the trip details
    Given the trip to pickup has started
    And the "visit details" request failed on the "P4 Start trip to pickup" screen
    And the "visit details" request has recovered
    When I tap "Retry"
    Then I should see the text "B-14, Malviya Nagar, New Delhi"

  @ui-state @negative
  Scenario: Going offline blocks the actions that need the server
    Given the trip to pickup has started
    And I am on the "P4 Start trip to pickup" screen
    When the device goes offline
    Then I should see the "offline banner" state
    And the "I've arrived" button should be disabled

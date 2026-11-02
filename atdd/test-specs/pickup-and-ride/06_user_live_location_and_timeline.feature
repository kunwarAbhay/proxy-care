# Screens: U1 Caretaker live location, U2 Visit timeline (User app)
# Source: proxy-care-ui-ux-state-for-api-design.md (PRD v2.3) §4 U1/U2, §2 location visibility + visit stage, §7 realtime; PRD 3.2, 3.3
# U1's waiting state before the trip starts is also covered in service-booking/06_caretaker_assigned.feature.
# Assumption: HEADING_TO_PICKUP highlights the "Pickup" step, as the trip to pickup has started. The design gives no mapping.
# Product decision (3 Nov 2026), overriding §2 and PRD 3.3: location broadcasting starts when the trip to pickup starts, with no toggle.
#
# Open design questions (no scenario until decided):
#   - Which U1 step applies to OWN_TRANSPORT_TO_HOSPITAL? "Ride" is the only transit step.
#   - What does U1 show when the caretaker's location stops updating?
#   - Does the pickup code stay visible on U1 after pickup is verified?
#   - Does the U2 banner show the amount? U2 has "no fares or charges", so this suite does not assert one.

@regression @user-app @pickup-and-ride @U1 @U2
Feature: User follows the caretaker and the ride
  As the User sponsoring a visit
  I want to see the caretaker's live location and every event of the trip
  So that I know my family member has been picked up and is on the way

  Rules (context §2, §4, §7, PRD 3.3):
    - The user sees the caretaker's live location from the start of the trip to pickup until the visit is marked completed.
    - U1 progress has 5 steps: Assigned, Pickup, Ride, Hospital, Home.
    - U2 shows events only, with no fares or charges.

  Background:
    Given I am logged in to the User app as "Rohan Mehta"
    And my booking "PC-2481" for patient "Kamla Mehta" has the caretaker "Anita Verma"
    And the pickup code is "4821"

  # ---------- U1 Caretaker live location ----------

  @smoke @happy-path
  Scenario: U1 shows the map, the ETA, the caretaker and the pickup code
    Given the booking is in state "ASSIGNED" with stage "HEADING_TO_PICKUP"
    And live location sharing is active
    When I open the "U1 Caretaker live location" screen
    Then I should see the map with the caretaker pin and the patient's home
    And I should see the ETA
    And I should see the progress steps "Assigned, Pickup, Ride, Hospital, Home"
    And I should see the text "Anita Verma"
    And I should see the text "4821"
    And the "Call caretaker" button should be enabled
    And the "View visit timeline" button should be enabled

  @navigation
  Scenario Outline: U1 opens from Home and from the assigned screen
    Given the booking is in state "ASSIGNED" with stage "HEADING_TO_PICKUP"
    And I am on the "<origin>" screen
    When I tap "<action>"
    Then I should be on the "U1 Caretaker live location" screen

    Examples:
      | origin                | action               |
      | B1 Home               | Track caretaker live |
      | B6 Caretaker assigned | Track visit live     |

  @ui-state
  Scenario: The Assigned step is highlighted before the trip starts
    Given the booking is in state "ASSIGNED"
    And live location sharing is inactive
    When I open the "U1 Caretaker live location" screen
    Then the progress step "Assigned" should be highlighted

  @ui-state
  Scenario Outline: The progress step follows the visit stage
    Given the booking is in state "<state>" with stage "<stage>"
    When I open the "U1 Caretaker live location" screen
    Then the progress step "<step>" should be highlighted

    Examples:
      | state       | stage             | step     |
      | ASSIGNED    | HEADING_TO_PICKUP | Pickup   |
      | IN_PROGRESS | PICKED_UP         | Pickup   |
      | IN_PROGRESS | RIDE_TO_HOSPITAL  | Ride     |
      | IN_PROGRESS | AT_HOSPITAL       | Hospital |

  @smoke @realtime
  Scenario: Caretaker location updates move the pin and the ETA
    Given the booking is in state "ASSIGNED" with stage "HEADING_TO_PICKUP"
    And live location sharing is active
    And I am on the "U1 Caretaker live location" screen
    When the caretaker's location changes
    Then the caretaker pin should move without a refresh
    And the ETA should update without a refresh

  @ui-state
  Scenario: No caretaker pin is shown before the trip starts
    Given the booking is in state "ASSIGNED"
    And live location sharing is inactive
    When I open the "U1 Caretaker live location" screen
    Then I should not see the caretaker pin

  @realtime
  Scenario: The pin appears when the caretaker starts the trip
    Given the booking is in state "ASSIGNED"
    And live location sharing is inactive
    And I am on the "U1 Caretaker live location" screen
    When the caretaker starts the trip to pickup
    Then I should see the caretaker pin without a refresh

  @realtime
  Scenario: The pin stays when the caretaker goes offline for visit requests
    Given the booking is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And live location sharing is active
    And I am on the "U1 Caretaker live location" screen
    When the caretaker toggles offline on the "P1 Home" screen
    Then I should see the caretaker pin

  @happy-path
  Scenario: Live location continues during the ride
    Given the booking is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And live location sharing is active
    When I open the "U1 Caretaker live location" screen
    Then I should see the caretaker pin

  @happy-path @device
  Scenario Outline: Call caretaker opens the dialer
    Given the booking is in state "ASSIGNED" with stage "HEADING_TO_PICKUP"
    And I am on the "<screen>" screen
    When I tap "Call caretaker"
    Then the phone dialer should open with the number of "Anita Verma"

    Examples:
      | screen                     |
      | U1 Caretaker live location |
      | U2 Visit timeline          |

  @negative @pending-design
  Scenario: The ride and the pin still work when map tiles fail to load
    Given the booking is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And the map tiles fail to load
    When I open the "U1 Caretaker live location" screen
    Then I should see the ETA
    And the "View visit timeline" button should be enabled

  # ---------- U2 Visit timeline ----------

  @smoke @happy-path
  Scenario: U2 lists the events in order with times and the current step
    Given the booking is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And the booking has the timeline events:
      | event                 | time     |
      | Pickup OTP verified   | 09:58 AM |
      | Ride Partner Assigned | 10:02 AM |
      | Ride Partner Arrived  | 10:08 AM |
      | Trip Started          | 10:10 AM |
    When I open the "U2 Visit timeline" screen
    Then I should see those timeline events in that order with their times
    And the timeline event "Trip Started" should be highlighted

  @ui-state
  Scenario: U2 shows only the assignment step before anything has happened
    Given the booking is in state "ASSIGNED"
    And the booking has no pickup or ride events
    When I open the "U2 Visit timeline" screen
    Then I should not see the timeline event "Pickup OTP verified"
    And I should not see the timeline event "Trip Started"

  @access-control
  Scenario: U2 never shows fares or charges
    Given the booking is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And the ride has the fare estimate "₹320"
    And the ride has the final fare "₹340"
    And the booking has the timeline events:
      | event          | time     |
      | Trip Completed | 10:40 AM |
    When I open the "U2 Visit timeline" screen
    Then no timeline event should show a fare or charge

  @realtime
  Scenario: Pickup verification appears on the timeline
    Given the booking is in state "ASSIGNED" with stage "HEADING_TO_PICKUP"
    And I am on the "U2 Visit timeline" screen
    When the caretaker confirms arrival with the correct code
    Then the timeline event "Pickup OTP verified" should appear without a refresh

  @realtime
  Scenario: The Home stage badge changes when pickup is verified
    Given the booking is in state "ASSIGNED" with stage "HEADING_TO_PICKUP"
    And I am on the "B1 Home" screen
    When the caretaker confirms arrival with the correct code
    Then I should see the stage badge "Patient picked up" without a refresh

  @realtime
  Scenario Outline: Each ride event appears on the timeline
    Given the booking is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And I am on the "U2 Visit timeline" screen
    When the ride partner reports "<event>"
    Then the timeline event "<label>" should appear without a refresh

    Examples:
      | event                 | label                 |
      | RIDE_PARTNER_ASSIGNED | Ride Partner Assigned |
      | RIDE_PARTNER_ARRIVED  | Ride Partner Arrived  |
      | TRIP_STARTED          | Trip Started          |
      | TRIP_COMPLETED        | Trip Completed        |

  @negative
  Scenario Outline: Own transport shows no ride events
    Given the booking is in state "IN_PROGRESS" with stage "OWN_TRANSPORT_TO_HOSPITAL"
    When I open the "U2 Visit timeline" screen
    Then I should not see the timeline event "<label>"

    Examples:
      | label                 |
      | Ride Partner Assigned |
      | Ride Partner Arrived  |
      | Trip Started          |
      | Trip Completed        |

  @smoke @realtime
  Scenario: A ride payment request shows a banner on U2
    Given the booking is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And I am on the "U2 Visit timeline" screen
    When the caretaker requests the ride fare
    Then I should see the ride payment request banner without a refresh

  @navigation
  Scenario: The ride payment banner opens U2b
    Given the booking is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And the booking has a "RIDE_TO_HOSPITAL" payment request for "₹340"
    And I am on the "U2 Visit timeline" screen
    When I tap the ride payment request banner
    Then I should be on the "U2b Ride payment request" screen

  @negative
  Scenario: No payment banner while the trip is running
    Given the booking is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And the latest ride event is "TRIP_STARTED"
    When I open the "U2 Visit timeline" screen
    Then I should not see the ride payment request banner

  @navigation
  Scenario: The ongoing visit arrow on Home opens U2
    Given the booking is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And I am on the "B1 Home" screen
    When I open the ongoing visit
    Then I should be on the "U2 Visit timeline" screen

  @navigation
  Scenario Outline: U1 and U2 link to each other
    Given the booking is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And I am on the "<origin>" screen
    When I tap "<action>"
    Then I should be on the "<target>" screen

    Examples:
      | origin                     | action              | target                     |
      | U1 Caretaker live location | View visit timeline | U2 Visit timeline          |
      | U2 Visit timeline          | Track live          | U1 Caretaker live location |

  @navigation @device
  Scenario Outline: Back returns to the screen the tracking was opened from
    Given the booking is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And I opened the "<screen>" screen from the "B1 Home" screen
    When I press the device back button
    Then I should be on the "B1 Home" screen

    Examples:
      | screen                     |
      | U1 Caretaker live location |
      | U2 Visit timeline          |

  # ---------- Loading / error / offline ----------

  @ui-state
  Scenario Outline: Skeleton while the screen loads
    Given the booking is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And the "visit data" request is slow
    When I open the "<screen>" screen
    Then I should see the "loading skeleton" state

    Examples:
      | screen                     |
      | U1 Caretaker live location |
      | U2 Visit timeline          |

  @ui-state @negative
  Scenario Outline: A failed load shows an error with Retry
    Given the booking is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And the "visit data" request will fail
    When I open the "<screen>" screen
    Then I should see the "error" state
    And the "Retry" button should be enabled

    Examples:
      | screen                     |
      | U1 Caretaker live location |
      | U2 Visit timeline          |

  @ui-state
  Scenario Outline: Retry reloads the screen
    Given the booking is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And the "visit data" request failed on the "<screen>" screen
    And the "visit data" request has recovered
    When I tap "Retry"
    Then I should not see the "error" state
    And I should be on the "<screen>" screen

    Examples:
      | screen                     |
      | U1 Caretaker live location |
      | U2 Visit timeline          |

  @ui-state @realtime
  Scenario: Missed events are caught up after reconnecting
    Given the booking is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And I am on the "U2 Visit timeline" screen
    And the device is offline
    And the ride partner has reported "TRIP_STARTED"
    When the device comes back online
    Then the timeline event "Trip Started" should appear without a refresh
    And I should not see the "offline banner" state

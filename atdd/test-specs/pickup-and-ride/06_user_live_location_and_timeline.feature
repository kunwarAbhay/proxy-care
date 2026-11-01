# Screens: U1 Caretaker live location, U2 Visit timeline (User app)
# Source: proxy-care-ui-ux-state-for-api-design.md (PRD v2.3) §4 U1/U2, §2 location visibility + visit stage, §7 realtime; PRD 3.2, 3.3
# U1's waiting state before the trip starts is also covered in service-booking/06_caretaker_assigned.feature.
# Assumption: HEADING_TO_PICKUP highlights the "Pickup" step, as the trip to pickup has started. The design gives no mapping.
# §2 does not say which U1 step applies to OWN_TRANSPORT_TO_HOSPITAL, so that case is @pending-design.

@user-app @pickup-and-ride @U1 @U2
Feature: User follows the caretaker and the ride
  As the User sponsoring a visit
  I want to see the caretaker's live location and every event of the trip
  So that I know my family member has been picked up and is on the way

  Rules (context §2, §4, §7, PRD 3.3):
    - The user sees the caretaker's live location once the caretaker turns on "Reaching pickup location".
    - U1 progress has 5 steps: Assigned, Pickup, Ride, Hospital, Home.
    - U2 shows events only, with no fares or charges.

  Background:
    Given I am logged in to the User app as "Rohan Mehta"
    And booking "PC-2481" for patient "Kamla Mehta" is in state "ASSIGNED" with pickup at "10:00 AM"
    And the assigned caretaker is "Anita Verma"
    And the pickup code for "PC-2481" is "4821"

  # ---------- U1 Caretaker live location ----------

  @smoke
  Scenario: U1 shows the map, the ETA, the caretaker and the pickup code
    Given booking "PC-2481" has stage "HEADING_TO_PICKUP"
    And live location sharing is active for booking "PC-2481"
    When I open the "U1 Caretaker live location" screen
    Then I should see a live map with the caretaker pin and the patient home pin
    And I should see the ETA
    And I should see the progress steps "Assigned", "Pickup", "Ride", "Hospital" and "Home"
    And I should see the caretaker card for "Anita Verma"
    And I should see the pickup code "4821"
    And I should see the actions "Call caretaker" and "View visit timeline"

  @navigation
  Scenario Outline: U1 can be opened from Home and from the assigned screen
    Given I am on the "<origin>" screen
    When I tap "<action>"
    Then I should be on the "U1 Caretaker live location" screen

    Examples:
      | origin                | action               |
      | B1 Home               | Track caretaker live |
      | B6 Caretaker assigned | Track visit live     |

  Scenario Outline: The progress step follows the visit stage
    Given booking "PC-2481" has stage "<stage>"
    When I open the "U1 Caretaker live location" screen
    Then the progress step "<step>" should be highlighted

    Examples:
      | stage             | step     |
      | HEADING_TO_PICKUP | Pickup   |
      | PICKED_UP         | Pickup   |
      | RIDE_TO_HOSPITAL  | Ride     |
      | AT_HOSPITAL       | Hospital |

  @pending-design
  Scenario: Progress step while travelling by own transport
    Given booking "PC-2481" has stage "OWN_TRANSPORT_TO_HOSPITAL"
    When I open the "U1 Caretaker live location" screen
    Then it should be confirmed by design whether the "Ride" step is highlighted

  @smoke @realtime
  Scenario: Caretaker location updates move the pin and the ETA
    Given live location sharing is active for booking "PC-2481"
    And I am on the "U1 Caretaker live location" screen
    When the caretaker's location changes
    Then the caretaker pin should move without a manual refresh
    And the ETA should update without a manual refresh

  @realtime
  Scenario: The map appears when the caretaker starts sharing
    Given live location sharing is not active for booking "PC-2481"
    And I am on the "U1 Caretaker live location" screen
    Then I should not see the caretaker pin
    When the caretaker turns on the "Reaching pickup location" toggle
    Then I should see the caretaker pin without a manual refresh

  @realtime
  Scenario: Live location continues during the ride
    Given booking "PC-2481" is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And live location sharing is active for booking "PC-2481"
    When I open the "U1 Caretaker live location" screen
    Then I should see the caretaker pin
    And the progress step "Ride" should be highlighted

  @happy-path
  Scenario: Call caretaker opens the dialer
    Given I am on the "U1 Caretaker live location" screen
    When I tap "Call caretaker"
    Then the phone dialer should open with the number of "Anita Verma"

  @navigation
  Scenario: U1 links to the visit timeline
    Given I am on the "U1 Caretaker live location" screen
    When I tap "View visit timeline"
    Then I should be on the "U2 Visit timeline" screen

  @pending-design
  Scenario: The caretaker's location stops updating
    Given live location sharing is active for booking "PC-2481"
    When no location update has arrived for a long time
    Then the stale location state should be confirmed by design

  @pending-design
  Scenario: The pickup code after the pickup has been verified
    Given booking "PC-2481" is in state "IN_PROGRESS" with stage "PICKED_UP"
    When I open the "U1 Caretaker live location" screen
    Then it should be confirmed by design whether the pickup code stays visible

  # ---------- U2 Visit timeline ----------

  @smoke
  Scenario: U2 lists the events in order with times and the current step
    Given booking "PC-2481" is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And the following timeline events have happened:
      | event                 | time     |
      | Pickup OTP verified   | 09:58 AM |
      | Ride Partner Assigned | 10:02 AM |
      | Ride Partner Arrived  | 10:08 AM |
      | Trip Started          | 10:10 AM |
    When I open the "U2 Visit timeline" screen
    Then I should see the events in that order with their times
    And the event "Trip Started" should be highlighted as the current step
    And I should see the actions "Call caretaker" and "Track live"

  @access-control
  Scenario: U2 never shows fares or charges
    Given booking "PC-2481" is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And the ride has the fare estimate "₹320" and the final fare "₹340"
    And the following timeline events have happened:
      | event          | time     |
      | Trip Completed | 10:40 AM |
    When I open the "U2 Visit timeline" screen
    Then no timeline event should show a fare or charge

  @realtime
  Scenario: Pickup verification appears on the timeline
    Given I am on the "U2 Visit timeline" screen
    When the caretaker confirms arrival with the right code
    Then the event "Pickup OTP verified" should appear without a manual refresh
    And the ongoing visit card on Home should show the stage badge "Patient picked up"

  @realtime
  Scenario Outline: Each ride event appears on the timeline
    Given booking "PC-2481" is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And I am on the "U2 Visit timeline" screen
    When the ride partner reports "<event>"
    Then the event "<label>" should appear without a manual refresh

    Examples:
      | event                 | label                 |
      | RIDE_PARTNER_ASSIGNED | Ride Partner Assigned |
      | RIDE_PARTNER_ARRIVED  | Ride Partner Arrived  |
      | TRIP_STARTED          | Trip Started          |
      | TRIP_COMPLETED        | Trip Completed        |

  @negative
  Scenario: Own transport shows no ride events
    Given booking "PC-2481" is in state "IN_PROGRESS" with stage "OWN_TRANSPORT_TO_HOSPITAL"
    When I open the "U2 Visit timeline" screen
    Then I should not see the events "Ride Partner Assigned", "Ride Partner Arrived", "Trip Started" or "Trip Completed"

  @smoke @realtime @navigation
  Scenario: A ride payment request banner opens U2b
    Given booking "PC-2481" is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And I am on the "U2 Visit timeline" screen
    When the caretaker requests the ride fare from the family
    Then I should see a ride payment request banner
    When I tap the banner
    Then I should be on the "U2b Ride payment request" screen

  @negative
  Scenario: No payment banner while the trip is running
    Given booking "PC-2481" is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And the latest ride event is "TRIP_STARTED"
    When I open the "U2 Visit timeline" screen
    Then I should not see a ride payment request banner

  @happy-path
  Scenario: Call caretaker from the timeline
    Given I am on the "U2 Visit timeline" screen
    When I tap "Call caretaker"
    Then the phone dialer should open with the number of "Anita Verma"

  @navigation
  Scenario Outline: U2 can be reached and links back to live tracking
    Given I am on the "<origin>" screen
    When I tap "<action>"
    Then I should be on the "<target>" screen

    Examples:
      | origin                     | action                  | target                     |
      | B1 Home                    | the ongoing visit arrow | U2 Visit timeline          |
      | U1 Caretaker live location | View visit timeline     | U2 Visit timeline          |
      | U2 Visit timeline          | Track live              | U1 Caretaker live location |

  # ---------- Loading / error / offline ----------

  @ui-state
  Scenario Outline: Skeleton while the screen loads
    Given the visit data request is slow
    When I open the "<screen>" screen
    Then I should see skeleton placeholders

    Examples:
      | screen                     |
      | U1 Caretaker live location |
      | U2 Visit timeline          |

  @ui-state @negative
  Scenario Outline: Error state with retry when the screen fails to load
    Given the visit data request fails
    When I open the "<screen>" screen
    Then I should see an error with a "Retry" button
    When the visit data request succeeds
    And I tap "Retry"
    Then I should see the "<screen>" content

    Examples:
      | screen                     |
      | U1 Caretaker live location |
      | U2 Visit timeline          |

  @ui-state @realtime
  Scenario: Missed events are caught up after reconnecting
    Given booking "PC-2481" is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And I am on the "U2 Visit timeline" screen
    And the device goes offline
    And the ride partner reports "TRIP_STARTED" while I am offline
    When the device comes back online
    Then the event "Trip Started" should appear with its original time
    And the offline banner should disappear

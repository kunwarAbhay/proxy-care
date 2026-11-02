# Screen: P8a Ride status (Caretaker app)
# Source: proxy-care-ui-ux-state-for-api-design.md (PRD v2.3) §5 P8a, §1 Ride + Payment request, §2 ride events + visit stage, §7 realtime; PRD 3.2
# §2 resumes stage RIDE_TO_HOSPITAL at P8a even after the fare is requested, so P8a must reuse the request instead of creating another.
#
# Open design questions (no scenario until decided):
#   - "Cancel ride": confirmation, cancellation charge, next screen, and whether it is available after TRIP_STARTED.
#   - What happens when the ride partner or driver cancels, or the driver never arrives? Ride events have no cancelled status.
#   - On resume, what control takes the caretaker from P8a to an existing request's P9a? Scenarios use "I open the existing fare request".

@regression @caretaker-app @pickup-and-ride @P8a
Feature: Caretaker follows the ride to the hospital
  As a Caretaker travelling with the patient
  I want live ride status and driver details
  So that I can meet the driver, follow the trip and request the fare when it ends

  Rules (context §1, §2, §5, §7):
    - Ride events: RIDE_PARTNER_ASSIGNED -> RIDE_PARTNER_ARRIVED -> TRIP_STARTED -> TRIP_COMPLETED.
    - "Request ₹X from family" appears only on TRIP_COMPLETED.
    - Tapping it creates a RIDE_TO_HOSPITAL payment request for the final fare and opens P9a.

  Background:
    Given today is "2026-11-02"
    And I am logged in to the Caretaker app as "Anita Verma"
    And I am assigned to booking "PC-2481" for patient "Kamla Mehta"
    And the booking is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And the sponsoring user is "Rohan Mehta"
    And the booking has a ride for leg "TO_HOSPITAL":
      | provider | vehicle | driver      | plate         | ride_pin | fare_estimate |
      | Uber     | Cab     | Sunil Yadav | DL 3C AB 1234 | 7302     | ₹320          |

  # ---------- Display ----------

  @smoke @happy-path
  Scenario: P8a shows the driver, the ride PIN and the fare estimate
    Given the latest ride event is "RIDE_PARTNER_ASSIGNED"
    When I open the "P8a Ride status" screen
    Then I should see the text "Sunil Yadav"
    And I should see the text "DL 3C AB 1234"
    And I should see the text "Cab"
    And I should see the text "7302"
    And I should see the text "₹320"
    And I should see the ride events "Ride Partner Assigned, Ride Partner Arrived, Trip Started, Trip Completed"
    And the "Call driver" button should be enabled
    And the "Cancel ride" button should be visible

  @ui-state
  Scenario Outline: Ride progress and the fare request follow the latest event
    Given the latest ride event is "<event>"
    When I open the "P8a Ride status" screen
    Then the ride events up to "<label>" should show their times
    And the ride events after "<label>" should show no time
    And the "Request from family" button should be <request>

    Examples:
      | event                 | label                 | request |
      | RIDE_PARTNER_ASSIGNED | Ride Partner Assigned | hidden  |
      | RIDE_PARTNER_ARRIVED  | Ride Partner Arrived  | hidden  |
      | TRIP_STARTED          | Trip Started          | hidden  |
      | TRIP_COMPLETED        | Trip Completed        | visible |

  # ---------- Realtime ride events ----------

  @smoke @realtime
  Scenario Outline: Each ride event arrives without a manual refresh
    Given the latest ride event is "<previous>"
    And I am on the "P8a Ride status" screen
    When the ride partner reports "<event>"
    Then the ride event "<label>" should show its time without a refresh
    And the sponsoring user should have the timeline event "<label>"

    Examples:
      | previous              | event                | label                |
      | RIDE_PARTNER_ASSIGNED | RIDE_PARTNER_ARRIVED | Ride Partner Arrived |
      | RIDE_PARTNER_ARRIVED  | TRIP_STARTED         | Trip Started         |
      | TRIP_STARTED          | TRIP_COMPLETED       | Trip Completed       |

  @negative @api
  Scenario: A duplicate ride event is recorded once
    Given the ride partner reported "TRIP_STARTED" at "10:20 AM"
    When the ride partner reports "TRIP_STARTED" at "10:21 AM"
    Then the ride event "TRIP_STARTED" should have the time "10:20 AM"
    And the sponsoring user should have 1 "Trip Started" timeline event

  @negative @api
  Scenario: A late ride event does not move the ride backwards
    Given the latest ride event is "TRIP_STARTED"
    When the ride partner reports "RIDE_PARTNER_ARRIVED"
    Then the latest ride event should be "TRIP_STARTED"

  @ui-state @realtime
  Scenario: Missed events are caught up after reconnecting
    Given the latest ride event is "RIDE_PARTNER_ARRIVED"
    And I am on the "P8a Ride status" screen
    And the device is offline
    And the ride partner has reported "TRIP_STARTED"
    When the device comes back online
    Then the ride event "Trip Started" should show its time without a refresh
    And I should not see the "offline banner" state

  # ---------- Requesting the fare ----------

  @smoke @happy-path
  Scenario: Requesting the final fare from the family
    Given the latest ride event is "TRIP_COMPLETED"
    And the ride has the final fare "₹340"
    And I am on the "P8a Ride status" screen
    When I tap "Request ₹340 from family"
    Then the booking should have 1 "RIDE_TO_HOSPITAL" payment request for "₹340"
    And the ride payment request should be requested by "Anita Verma"
    And the ride payment request should have the payee "ride partner"
    And the ride payment request should have status "REQUESTED"
    And I should be on the "P9a Ride payment" screen
    And the sponsoring user should get a ride payment request notification

  @ui-validation
  Scenario Outline: The request uses the final fare, not the estimate
    Given the latest ride event is "TRIP_COMPLETED"
    And the ride has the fare estimate "<estimate>"
    And the ride has the final fare "<final>"
    When I open the "P8a Ride status" screen
    Then the "Request <final> from family" button should be enabled

    Examples: Final fare against the estimate
      | estimate | final |
      | ₹320     | ₹320  |
      | ₹320     | ₹340  |
      | ₹320     | ₹295  |

    Examples: Thousands separator
      | estimate | final  |
      | ₹980     | ₹1,020 |

  @negative
  Scenario: A double tap on the request creates one payment request
    Given the latest ride event is "TRIP_COMPLETED"
    And the ride has the final fare "₹340"
    And I am on the "P8a Ride status" screen
    When I double tap "Request ₹340 from family"
    Then the booking should have 1 "RIDE_TO_HOSPITAL" payment request for "₹340"

  @negative
  Scenario: A failed request keeps the caretaker on P8a
    Given the latest ride event is "TRIP_COMPLETED"
    And the ride has the final fare "₹340"
    And the "create payment request" request will fail
    And I am on the "P8a Ride status" screen
    When I tap "Request ₹340 from family"
    Then I should see the "error" state
    And I should be on the "P8a Ride status" screen
    And the "Request ₹340 from family" button should be enabled
    And the booking should have 0 "RIDE_TO_HOSPITAL" payment requests

  @negative @api
  Scenario Outline: The fare cannot be requested before the trip is completed
    Given the latest ride event is "<event>"
    When the caretaker client requests the ride fare
    Then the server should reject the request
    And the booking should have 0 "RIDE_TO_HOSPITAL" payment requests

    Examples:
      | event                 |
      | RIDE_PARTNER_ASSIGNED |
      | RIDE_PARTNER_ARRIVED  |
      | TRIP_STARTED          |

  @negative @pending-design
  Scenario: The fare cannot be requested until the final fare is known
    Given the latest ride event is "TRIP_COMPLETED"
    And the ride has no final fare yet
    When I open the "P8a Ride status" screen
    Then the "Request from family" button should be hidden

  @navigation @negative
  Scenario: Resuming after the fare was requested does not create a second request
    Given the latest ride event is "TRIP_COMPLETED"
    And the booking has a "RIDE_TO_HOSPITAL" payment request for "₹340"
    And I am on the "P8a Ride status" screen
    When I open the existing fare request
    Then I should be on the "P9a Ride payment" screen
    And the booking should have 1 "RIDE_TO_HOSPITAL" payment request for "₹340"

  # ---------- Actions ----------

  @happy-path @device
  Scenario: Call driver opens the dialer
    Given I am on the "P8a Ride status" screen
    When I tap "Call driver"
    Then the phone dialer should open with the number of "Sunil Yadav"

  # ---------- Navigation and resume ----------

  @navigation
  Scenario: The resume arrow opens P8a for stage RIDE_TO_HOSPITAL
    Given I am on the "P1 Home" screen
    When I resume the ongoing visit
    Then I should be on the "P8a Ride status" screen

  @navigation @device
  Scenario: Back from P8a does not reopen booking
    Given I opened the "P8a Ride status" screen from the "P7a Book ride" screen
    When I press the device back button
    Then I should not be on the "P7a Book ride" screen
    And the booking should have 1 ride for leg "TO_HOSPITAL"

  @ui-state @device
  Scenario: Reopening the app shows the latest ride status
    Given the latest ride event is "RIDE_PARTNER_ARRIVED"
    And the app is closed
    And the ride partner has reported "TRIP_STARTED"
    When I reopen the app
    And I resume the ongoing visit
    Then I should be on the "P8a Ride status" screen
    And the ride event "Trip Started" should show its time without a refresh

  # ---------- Loading / error / offline ----------

  @ui-state
  Scenario: Skeleton while the ride loads
    Given the "ride status" request is slow
    When I open the "P8a Ride status" screen
    Then I should see the "loading skeleton" state

  @ui-state @negative
  Scenario: A failed load shows an error with Retry
    Given the "ride status" request will fail
    When I open the "P8a Ride status" screen
    Then I should see the "error" state
    And the "Retry" button should be enabled

  @ui-state
  Scenario: Retry reloads the ride
    Given the "ride status" request failed on the "P8a Ride status" screen
    And the "ride status" request has recovered
    When I tap "Retry"
    Then I should see the text "Sunil Yadav"

  @ui-state @negative
  Scenario: Going offline blocks the fare request
    Given the latest ride event is "TRIP_COMPLETED"
    And the ride has the final fare "₹340"
    And I am on the "P8a Ride status" screen
    When the device goes offline
    Then I should see the "offline banner" state
    And the "Request ₹340 from family" button should be disabled

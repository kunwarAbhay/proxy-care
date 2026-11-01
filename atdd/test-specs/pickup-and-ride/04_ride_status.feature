# Screen: P8a Ride status (Caretaker app)
# Source: proxy-care-ui-ux-state-for-api-design.md (PRD v2.3) §5 P8a, §1 Ride + Payment request, §2 ride events + visit stage, §7 realtime; PRD 3.2
# The design lists "cancel ride" and "share trip" as actions but does not define their outcome, so the outcomes are @pending-design.
# §2 resumes stage RIDE_TO_HOSPITAL at P8a even after the fare is requested, so P8a must reuse the request instead of creating another.

@caretaker-app @pickup-and-ride @P8a
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
    And I am logged in to the Caretaker app as "Anita Verma" with KYC "APPROVED"
    And I am assigned to booking "PC-2481" for patient "Kamla Mehta"
    And booking "PC-2481" is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And the sponsoring user is "Rohan Mehta", relation "Son"
    And booking "PC-2481" has the ride for leg "TO_HOSPITAL":
      | field         | value         |
      | provider      | Uber          |
      | vehicle       | Cab           |
      | driver        | Sunil Yadav   |
      | plate         | DL 3C AB 1234 |
      | ride_pin      | 7302          |
      | fare_estimate | ₹320          |

  # ---------- Display ----------

  @smoke
  Scenario: P8a shows the driver, the ride PIN and the fare estimate
    Given the latest ride event is "RIDE_PARTNER_ASSIGNED"
    When I open the "P8a Ride status" screen
    Then I should see the driver "Sunil Yadav"
    And I should see the plate "DL 3C AB 1234"
    And I should see the vehicle "Cab"
    And I should see the ride PIN "7302"
    And I should see the fare estimate "₹320"
    And I should see the 4 ride events "Ride Partner Assigned", "Ride Partner Arrived", "Trip Started" and "Trip Completed"
    And I should see the actions "Call driver", "Share trip" and "Cancel ride"

  Scenario Outline: Ride event progress and the fare request follow the latest event
    Given the latest ride event is "<event>"
    When I open the "P8a Ride status" screen
    Then the ride events up to "<label>" should show their times
    And the later ride events should show no time
    And the "Request from family" button should be <request>

    Examples:
      | event                 | label                 | request     |
      | RIDE_PARTNER_ASSIGNED | Ride Partner Assigned | not visible |
      | RIDE_PARTNER_ARRIVED  | Ride Partner Arrived  | not visible |
      | TRIP_STARTED          | Trip Started          | not visible |
      | TRIP_COMPLETED        | Trip Completed        | visible     |

  # ---------- Realtime ride events ----------

  @smoke @realtime
  Scenario: Ride events arrive without a manual refresh
    Given I am on the "P8a Ride status" screen
    And the latest ride event is "RIDE_PARTNER_ASSIGNED"
    When the ride partner reports "RIDE_PARTNER_ARRIVED"
    Then "Ride Partner Arrived" should show its time without a manual refresh
    When the ride partner reports "TRIP_STARTED"
    Then "Trip Started" should show its time without a manual refresh
    When the ride partner reports "TRIP_COMPLETED"
    Then "Trip Completed" should show its time without a manual refresh
    And I should see the "Request from family" button

  @realtime
  Scenario: Ride events also reach the user's timeline
    Given I am on the "P8a Ride status" screen
    When the ride partner reports "TRIP_STARTED"
    Then "Rohan Mehta" should see "Trip Started" on the "U2 Visit timeline" screen

  @negative @api
  Scenario: A duplicate ride event is recorded once
    Given the ride partner has reported "TRIP_STARTED" at "10:20 AM"
    When the ride partner reports "TRIP_STARTED" again at "10:21 AM"
    Then "Trip Started" should still show "10:20 AM"
    And "Rohan Mehta" should have only one "Trip Started" timeline event

  @negative @api
  Scenario: A late ride event does not move the ride backwards
    Given the latest ride event is "TRIP_STARTED"
    When the ride partner reports "RIDE_PARTNER_ARRIVED"
    Then the latest ride event should still be "TRIP_STARTED"
    And the "Request from family" button should be not visible

  @ui-state @realtime
  Scenario: Missed events are caught up after reconnecting
    Given I am on the "P8a Ride status" screen
    And the latest ride event is "RIDE_PARTNER_ARRIVED"
    And the device goes offline
    And the ride partner reports "TRIP_STARTED" while I am offline
    When the device comes back online
    Then "Trip Started" should show its time
    And the offline banner should disappear

  # ---------- Requesting the fare ----------

  @smoke @happy-path
  Scenario: Requesting the final fare from the family
    Given the latest ride event is "TRIP_COMPLETED"
    And the final fare of the ride is "₹340"
    And I am on the "P8a Ride status" screen
    When I tap "Request ₹340 from family"
    Then a "RIDE_TO_HOSPITAL" payment request for "₹340" should be created for booking "PC-2481"
    And the payment request should be requested by "Anita Verma"
    And the payment request status should be "REQUESTED"
    And I should be on the "P9a Ride payment" screen
    And "Rohan Mehta" should receive a ride payment request notification

  Scenario Outline: The request uses the final fare, not the estimate
    Given the latest ride event is "TRIP_COMPLETED"
    And the fare estimate of the ride is "<estimate>"
    And the final fare of the ride is "<final>"
    When I open the "P8a Ride status" screen
    Then I should see the "Request <final> from family" button

    Examples:
      | estimate | final |
      | ₹320     | ₹320  |
      | ₹320     | ₹340  |
      | ₹320     | ₹295  |

  @negative
  Scenario: A double tap on the request creates one payment request
    Given the latest ride event is "TRIP_COMPLETED"
    And the final fare of the ride is "₹340"
    And I am on the "P8a Ride status" screen
    When I double tap "Request ₹340 from family"
    Then exactly one "RIDE_TO_HOSPITAL" payment request should exist for booking "PC-2481"

  @negative
  Scenario: Request failure keeps the caretaker on P8a
    Given the latest ride event is "TRIP_COMPLETED"
    And the final fare of the ride is "₹340"
    And the create payment request call will fail
    And I am on the "P8a Ride status" screen
    When I tap "Request ₹340 from family"
    Then I should see an error
    And I should remain on the "P8a Ride status" screen
    And the "Request ₹340 from family" button should be enabled
    And no "RIDE_TO_HOSPITAL" payment request should exist for booking "PC-2481"

  @negative @api
  Scenario Outline: The fare cannot be requested before the trip is completed
    Given the latest ride event is "<event>"
    When the app sends a create payment request call for the ride
    Then the server should reject the request
    And no "RIDE_TO_HOSPITAL" payment request should exist for booking "PC-2481"

    Examples:
      | event                 |
      | RIDE_PARTNER_ASSIGNED |
      | RIDE_PARTNER_ARRIVED  |
      | TRIP_STARTED          |

  @navigation @negative
  Scenario: Resuming after the fare was requested does not create a second request
    Given the latest ride event is "TRIP_COMPLETED"
    And a "RIDE_TO_HOSPITAL" payment request for "₹340" exists for booking "PC-2481"
    And booking "PC-2481" has stage "RIDE_TO_HOSPITAL"
    And I am on the "P1 Home" screen
    When I tap the resume arrow on the ongoing visit card
    Then I should be on the "P8a Ride status" screen
    When I continue to the fare request
    Then I should be on the "P9a Ride payment" screen
    And exactly one "RIDE_TO_HOSPITAL" payment request should exist for booking "PC-2481"

  # ---------- Actions ----------

  @happy-path
  Scenario: Call driver opens the dialer
    Given I am on the "P8a Ride status" screen
    When I tap "Call driver"
    Then the phone dialer should open with the driver's contact number

  @happy-path
  Scenario: Share trip opens the share sheet
    Given I am on the "P8a Ride status" screen
    When I tap "Share trip"
    Then the device share sheet should open

  # PRD 3.3 says the patient sees no location, so a share link must not reopen that visibility.
  @pending-design @security
  Scenario: What a shared trip link exposes
    Given I have shared the trip with someone
    Then the content of the link and whether it shows live location should be confirmed by design

  @pending-design
  Scenario: Cancelling the ride
    Given the latest ride event is "RIDE_PARTNER_ASSIGNED"
    And I am on the "P8a Ride status" screen
    When I tap "Cancel ride"
    Then the confirmation, any cancellation charge and the next screen should be confirmed by design
    And no "RIDE_TO_HOSPITAL" payment request should be created unless design defines a charge

  @pending-design
  Scenario: Cancelling the ride after the trip has started
    Given the latest ride event is "TRIP_STARTED"
    When I open the "P8a Ride status" screen
    Then it should be confirmed by design whether "Cancel ride" is available

  @pending-design
  Scenario: The ride partner or driver cancels the ride
    Given the latest ride event is "RIDE_PARTNER_ASSIGNED"
    When the ride partner reports that the ride was cancelled
    Then the alert and the rebooking route should be confirmed by design

  @pending-design
  Scenario: The driver does not arrive
    Given the latest ride event is "RIDE_PARTNER_ASSIGNED"
    And no ride event has arrived for a long time
    Then the timeout and the rebooking route should be confirmed by design

  # ---------- Navigation and resume ----------

  @navigation
  Scenario: Back from P8a does not reopen booking
    Given I reached the "P8a Ride status" screen from the "P7a Book ride" screen
    When I press the device back button
    Then I should not return to the "P7a Book ride" screen
    And exactly one ride should exist for leg "TO_HOSPITAL"

  @ui-state @navigation
  Scenario: Reopening the app resumes the ride with the latest status
    Given I am on the "P8a Ride status" screen
    And the latest ride event is "RIDE_PARTNER_ARRIVED"
    When I force close the Caretaker app
    And the ride partner reports "TRIP_STARTED"
    And I reopen the Caretaker app
    Then the ongoing visit card should show the stage badge "Ride to hospital"
    When I tap the resume arrow on the ongoing visit card
    Then I should be on the "P8a Ride status" screen
    And "Trip Started" should show its time

  # ---------- Loading / error ----------

  @ui-state
  Scenario: Skeleton while the ride loads
    Given the ride status request is slow
    When I open the "P8a Ride status" screen
    Then I should see skeleton placeholders

  @ui-state @negative
  Scenario: Error state with retry when the ride fails to load
    Given the ride status request fails
    When I open the "P8a Ride status" screen
    Then I should see an error with a "Retry" button
    When the ride status request succeeds
    And I tap "Retry"
    Then I should see the driver "Sunil Yadav"

  @ui-state @negative
  Scenario: Offline banner blocks the fare request
    Given the latest ride event is "TRIP_COMPLETED"
    And the final fare of the ride is "₹340"
    And I am on the "P8a Ride status" screen
    When the device goes offline
    Then I should see an offline banner
    And the "Request ₹340 from family" button should be disabled

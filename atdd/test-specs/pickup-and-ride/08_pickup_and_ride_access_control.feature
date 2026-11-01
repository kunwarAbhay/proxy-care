# Access control and data integrity across P4-P9a, U1, U2 and U2b
# Source: proxy-care-ui-ux-state-for-api-design.md (PRD v2.3) §2 booking state + location visibility, §3 shared payment pattern; PRD 3.2, 3.3
# Wording and error codes follow hospital-appointment/05_hospital_access_control.feature.

@pickup-and-ride @access-control @security
Feature: Role-based visibility and access rules during pickup and ride
  As the Proxy Care platform
  I want each role to see and do only what it is allowed to during pickup and ride
  So that the handover, the location data and the money stay trustworthy

  Background:
    Given booking "PC-2481" for patient "Kamla Mehta" is in state "IN_PROGRESS"
    And booking "PC-2481" is sponsored by user "Rohan Mehta"
    And caretaker "Anita Verma" is assigned to booking "PC-2481"
    And caretaker "Suresh Yadav" is an approved caretaker not assigned to booking "PC-2481"
    And user "Priya Nair" has no relation to booking "PC-2481"

  # ---------- Booking state gates ----------

  Scenario Outline: Ride screens are only reachable while the visit is in progress
    Given booking "PC-2481" is in state "<state>"
    And I am logged in to the Caretaker app as "Anita Verma"
    When I try to open the "P6 Book ride or skip" screen for booking "PC-2481"
    Then <outcome>

    Examples:
      | state       | outcome                                                        |
      | ASSIGNED    | I should see "Confirm pickup with the code first" and be on P3 |
      | IN_PROGRESS | I should be on the "P6 Book ride or skip" screen               |
      | CANCELLED   | I should see "This visit was cancelled" and be on P3           |

  @negative @api
  Scenario Outline: Ride APIs reject calls outside IN_PROGRESS
    Given booking "PC-2481" is in state "<state>"
    When caretaker "Anita Verma" calls "<endpoint>" for booking "PC-2481"
    Then the server should respond with error "BOOKING_NOT_IN_PROGRESS"
    And no ride or payment request should be created

    Examples:
      | state     | endpoint             |
      | ASSIGNED  | book ride            |
      | ASSIGNED  | record own transport |
      | COMPLETED | book ride            |
      | SETTLED   | book ride            |
      | CANCELLED | book ride            |
      | CANCELLED | record own transport |

  @negative @api
  Scenario Outline: The pickup code can only be verified while the booking is assigned
    Given booking "PC-2481" is in state "<state>"
    When caretaker "Anita Verma" submits the correct pickup code for booking "PC-2481"
    Then the server should reject the request
    And booking "PC-2481" should still be in state "<state>"

    Examples:
      | state     |
      | WAITING   |
      | COMPLETED |
      | SETTLED   |
      | CANCELLED |

  @negative @api
  Scenario: Only one active ride can exist for a leg
    Given booking "PC-2481" has an active ride for leg "TO_HOSPITAL"
    When caretaker "Anita Verma" calls "book ride" for leg "TO_HOSPITAL"
    Then the server should reject the request
    And exactly one active ride should exist for leg "TO_HOSPITAL"

  # ---------- Caretaker-only actions ----------

  @negative @api
  Scenario Outline: Only the assigned caretaker can run the pickup and ride flow
    Given I am authenticated as "<actor>"
    When I call "<endpoint>" for booking "PC-2481"
    Then the server should respond with "403 Forbidden"
    And nothing should change on booking "PC-2481"

    Examples:
      | actor        | endpoint               |
      | Suresh Yadav | start location sharing |
      | Suresh Yadav | verify pickup code     |
      | Suresh Yadav | resend pickup code     |
      | Suresh Yadav | book ride              |
      | Suresh Yadav | cancel ride            |
      | Suresh Yadav | request ride fare      |
      | Suresh Yadav | remind family          |
      | Rohan Mehta  | start location sharing |
      | Rohan Mehta  | verify pickup code     |
      | Rohan Mehta  | book ride              |
      | Rohan Mehta  | request ride fare      |
      | Priya Nair   | verify pickup code     |
      | Priya Nair   | book ride              |
      | Priya Nair   | request ride fare      |

  @negative
  Scenario: An unassigned caretaker cannot see the visit
    Given I am logged in to the Caretaker app as "Suresh Yadav"
    When I open a deep link to the "P4 Start trip to pickup" screen for booking "PC-2481"
    Then I should see "You don't have access to this visit"
    And I should be on the "P1 Home" screen
    And I should not see the patient's address or the family contact

  # ---------- User-only actions ----------

  @negative @api
  Scenario Outline: Only the sponsoring user can pay the ride
    Given a "₹340" "RIDE_TO_HOSPITAL" payment request exists for booking "PC-2481"
    And I am authenticated as "<actor>"
    When I call "create gateway order" for that payment request
    Then the server should respond with "403 Forbidden"
    And the payment request status should remain "REQUESTED"

    Examples:
      | actor        |
      | Anita Verma  |
      | Suresh Yadav |
      | Priya Nair   |

  @negative
  Scenario: Another user cannot open the ride payment request
    Given a "₹340" "RIDE_TO_HOSPITAL" payment request exists for booking "PC-2481"
    And I am logged in to the User app as "Priya Nair"
    When I open a deep link to that payment request
    Then I should see "This request isn't available"
    And I should not see the amount, route or driver

  # ---------- Location visibility ----------

  Scenario Outline: What each role sees of the location
    Given live location sharing is active for booking "PC-2481"
    And I am logged in as the "<role>"
    When I open the map for booking "PC-2481"
    Then I should see the caretaker's live location
    And I should see the patient's home address
    And I should not see a patient live location

    Examples:
      | role               |
      | assigned caretaker |
      | sponsoring user    |

  @negative @api
  Scenario Outline: Others cannot read the caretaker's location
    Given live location sharing is active for booking "PC-2481"
    When "<actor>" requests the caretaker's location for booking "PC-2481"
    Then the server should respond with "403 Forbidden"

    Examples:
      | actor        |
      | Suresh Yadav |
      | Priya Nair   |

  @negative @api
  Scenario: No location is available before sharing starts
    Given live location sharing is not active for booking "PC-2481"
    When "Rohan Mehta" requests the caretaker's location for booking "PC-2481"
    Then no location should be returned

  Scenario: The patient has no location access
    Given the patient "Kamla Mehta" has mobile "+919812345678"
    When the pickup code SMS is sent to "+919812345678"
    Then the SMS should contain the pickup code
    And the SMS should not contain a tracking link

  # ---------- Pickup code secrecy ----------

  @negative @api
  Scenario Outline: The caretaker never receives the pickup code
    Given I am logged in to the Caretaker app as "Anita Verma"
    When I open the "<screen>" screen for booking "PC-2481"
    Then I should not see the pickup code
    And the API responses for that screen should not contain the pickup code

    Examples:
      | screen                  |
      | P4 Start trip to pickup |
      | P5 Confirm arrival      |
      | P6 Book ride or skip    |
      | P8a Ride status         |
      | P9a Ride payment        |

  # ---------- Integrity of ride events and money ----------

  @negative @api
  Scenario: Ride events are only accepted from the ride partner integration
    Given the latest ride event is "TRIP_STARTED"
    When caretaker "Anita Verma" tries to report "TRIP_COMPLETED" for the ride
    Then the server should respond with "403 Forbidden"
    And the latest ride event should still be "TRIP_STARTED"

  @negative @api
  Scenario: A ride event with an invalid signature is rejected
    Given the latest ride event is "TRIP_STARTED"
    When a ride event "TRIP_COMPLETED" arrives with an invalid signature
    Then the event should be rejected
    And the latest ride event should still be "TRIP_STARTED"

  @negative @api
  Scenario: The caretaker cannot change the fare
    Given the final fare of the ride is "₹340"
    When the caretaker app sends a request ride fare call with amount "₹3,400"
    Then the payment request should be created for "₹340"

  @negative @api
  Scenario: The amount the user pays always comes from the payment request
    Given a "₹340" "RIDE_TO_HOSPITAL" payment request exists for booking "PC-2481"
    When the user app sends a gateway order request with amount "₹34"
    Then the gateway order should be created for "₹340"

  @negative @api
  Scenario: Gateway success is only trusted from the verified webhook
    Given a "₹340" "RIDE_TO_HOSPITAL" payment request is "PAYING"
    When the app reports "payment success" without a matching gateway webhook
    Then the payment request should remain "PAYING"
    And the caretaker's "Continue" button on P9a should stay disabled
    When a gateway webhook with a valid signature confirms the payment
    Then the payment request should become "PAID"
    And the caretaker's "Continue" button on P9a should be enabled

  @negative @api
  Scenario: Duplicate gateway webhooks are processed once
    Given a "₹340" "RIDE_TO_HOSPITAL" payment request was marked "PAID" by webhook event "evt_456"
    When the gateway delivers webhook event "evt_456" again
    Then the payment request should remain "PAID"
    And the caretaker should not receive a second "paid" event

  @negative @api
  Scenario: Own transport cannot produce a ride payment request
    Given booking "PC-2481" has stage "OWN_TRANSPORT_TO_HOSPITAL"
    And no ride exists for leg "TO_HOSPITAL"
    When caretaker "Anita Verma" calls "request ride fare" for booking "PC-2481"
    Then the server should reject the request
    And no "RIDE_TO_HOSPITAL" payment request should exist for booking "PC-2481"

  # ---------- Session ----------

  @negative
  Scenario: Expired session while confirming arrival
    Given booking "PC-2481" is in state "ASSIGNED"
    And I am logged in to the Caretaker app as "Anita Verma"
    And I am on the "P5 Confirm arrival" screen
    When my session expires
    And I enter "4821" in the "Pickup code" field
    And I tap "Confirm arrival"
    Then I should be asked to verify my mobile with OTP again
    And after verifying I should return to the "P5 Confirm arrival" screen
    And booking "PC-2481" should still be in state "ASSIGNED"

  @negative
  Scenario: Expired session while paying the ride
    Given a "₹340" "RIDE_TO_HOSPITAL" payment request exists for booking "PC-2481"
    And I am logged in to the User app as "Rohan Mehta"
    And I am on the "U2b Ride payment request" screen
    When my session expires
    And I tap "Approve & Pay ₹340"
    Then I should be asked to verify my mobile with OTP again
    And no gateway order should be created before I verify
    And after verifying I should return to the "U2b Ride payment request" screen

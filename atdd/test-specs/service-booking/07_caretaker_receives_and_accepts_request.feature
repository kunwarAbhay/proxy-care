# Screens: P1 Home, P2 New visit request (Caretaker app) - the dispatch side of WAITING -> ASSIGNED
# Source: proxy-care-api-context.md (PRD v2.3) §5 P1/P2, §2 booking state, §6 realtime;
#         Entity design: caretakers.is_online requires kyc_status = APPROVED; booking_offers
# v2.3: P1 shows an earnings wallet chip (earnings not yet withdrawn) that opens F4.

@caretaker-app @service-booking @dispatch @P1 @P2
Feature: Caretaker receives and accepts a visit request
  As a Caretaker
  I want to see nearby visit requests and accept them quickly
  So that I can take on visits that fit me

  Background:
    Given a User has paid for booking "PC-2481" for patient "Kamla Mehta"
    And booking "PC-2481" is in state "WAITING"
    And the patient is "F", "68", with mobility "WHEELCHAIR"
    And the patient lives in locality "Malviya Nagar"
    And the booking is for "2026-11-02" with pickup at "10:00 AM"
    And the hospital is "Max Super Speciality Hospital, Saket" with purposes "OPD, DIAGNOSTICS"

  # ---------- P1 Home ----------

  @smoke
  Scenario: Home shows the earnings wallet chip
    Given I am logged in to the Caretaker app as "Anita Verma" with KYC "APPROVED"
    And my earnings not yet withdrawn are "₹2,250"
    When I open the "P1 Home" screen
    Then I should see the earnings wallet chip showing "₹2,250"
    And I should see the online/offline toggle, upcoming visits, weekly earnings and visits done
    And I should see the bottom navigation with tabs "Home, Visits, Earnings, Profile"

  @empty-state
  Scenario: No upcoming visits
    Given I have no accepted visits
    When I open the "P1 Home" screen
    Then the upcoming visits section should show an empty state

  # ---------- Eligibility / access control ----------

  @access-control
  Scenario: Only approved caretakers can go online
    Given I am logged in to the Caretaker app with KYC status "SUBMITTED"
    When I open the "P1 Home" screen
    Then the online toggle should be disabled
    And I should see that I can go online after KYC approval

  @access-control
  Scenario Outline: Broadcast reaches only eligible caretakers
    Given caretaker "<name>" has KYC "<kyc>", is "<online>" and is "<distance>" from the patient
    When booking "PC-2481" is broadcast
    Then caretaker "<name>" should "<receives>" the request

    Examples:
      | name   | kyc       | online  | distance | receives    |
      | Anita  | APPROVED  | online  | 3 km     | receive     |
      | Meena  | APPROVED  | online  | 7.9 km   | receive     |
      | Sunita | APPROVED  | online  | 8.5 km   | not receive |
      | Ravi   | APPROVED  | offline | 2 km     | not receive |
      | Deepa  | SUBMITTED | offline | 1 km     | not receive |
      | Kiran  | REJECTED  | offline | 1 km     | not receive |

  @access-control
  Scenario: Unpaid bookings are never broadcast
    Given a booking "PC-2499" is in state "PAYMENT_PENDING"
    And I am an approved caretaker online 2 km from its patient
    Then I should not receive a request for "PC-2499"

  # ---------- Request display ----------

  @smoke @realtime
  Scenario: Online caretaker gets a new request alert
    Given I am logged in to the Caretaker app as "Anita Verma" with KYC "APPROVED"
    And I am online and 3 km from the patient
    When booking "PC-2481" is broadcast
    Then I should see a new request alert on the "P1 Home" screen
    And I should receive a push notification for the new visit request

  @smoke
  Scenario: Request details hide the full address before acceptance
    Given I am logged in to the Caretaker app as "Anita Verma" and online
    And I have a new request for booking "PC-2481"
    When I open the "P2 New visit request" screen
    Then I should see a countdown to respond
    And I should see the earning "₹750" for "3 h × ₹250"
    And I should see the date "Mon, 2 Nov" and pickup time "10:00 AM"
    And I should see the patient "F, 68, Wheelchair"
    And I should see pickup distance "3 km" and locality "Malviya Nagar"
    And I should see the hospital, purposes and hospital distance
    But I should not see the patient's name, mobile or full address
    And I should not see the pickup code

  @ui-state
  Scenario Outline: Earning reflects the patient's mobility wage
    Given the request is for a patient with mobility "<mobility>"
    When I open the "P2 New visit request" screen
    Then I should see the earning "<earning>" for "3 h × <wage>"

    Examples:
      | mobility   | wage | earning |
      | AMBULATORY | ₹200 | ₹600    |
      | WHEELCHAIR | ₹250 | ₹750    |
      | BEDRIDDEN  | ₹320 | ₹960    |

  # ---------- Accept / decline ----------

  @smoke @happy-path
  Scenario: First caretaker to accept wins
    Given I am "Anita Verma" viewing the request for "PC-2481"
    When I tap "Accept"
    Then booking "PC-2481" should move to state "ASSIGNED" with caretaker "Anita Verma"
    And I should be on the "P3 My visits" screen with the visit under "Upcoming"
    And I should now see the full pickup address and the family's instructions
    And the User should be notified that "Anita Verma" accepted

  @negative @realtime
  Scenario: Request already taken by another caretaker
    Given "Meena" and I both have the request for "PC-2481" open
    And "Meena" accepts first
    When I tap "Accept"
    Then I should see "This visit was taken by another caretaker"
    And booking "PC-2481" should still be assigned to "Meena"

  @realtime
  Scenario: Open request expires for others once someone accepts
    Given I am viewing the request for "PC-2481"
    When another caretaker accepts "PC-2481"
    Then my request screen should show "No longer available"
    And the "Accept" button should be disabled

  @negative
  Scenario: Simultaneous accepts assign exactly one caretaker
    Given 3 caretakers tap "Accept" for "PC-2481" at the same moment
    Then exactly one caretaker should be assigned to "PC-2481"
    And the other 2 should see "This visit was taken by another caretaker"

  @happy-path
  Scenario: Decline a request
    Given I am viewing the request for "PC-2481"
    When I tap "Decline"
    Then I should return to the "P1 Home" screen
    And the request for "PC-2481" should no longer be shown to me
    And booking "PC-2481" should remain "WAITING" for other caretakers

  @negative @ui-state
  Scenario: Request expires when the countdown ends
    Given I am viewing the request for "PC-2481"
    When the response countdown reaches zero
    Then the request should show "Expired"
    And the "Accept" button should be disabled

  @negative
  Scenario: Request cancelled by the family while open
    Given I am viewing the request for "PC-2481"
    When the User cancels booking "PC-2481"
    Then my request screen should show "Request cancelled by family"
    And the "Accept" button should be disabled

  @negative
  Scenario: Going offline removes pending requests
    Given I have an open request for "PC-2481"
    When I toggle offline on the "P1 Home" screen
    Then the request for "PC-2481" should no longer be shown to me

  @error
  Scenario: Accept fails due to a network error
    Given I am viewing the request for "PC-2481"
    And the accept API returns a network error
    When I tap "Accept"
    Then I should see "Couldn't accept. Check your connection."
    And the "Accept" button should be enabled if the countdown has not ended

  @ui-state
  Scenario: Accept shows processing and prevents double taps
    Given I am viewing the request for "PC-2481"
    And the accept API responds slowly
    When I tap "Accept"
    Then the "Accept" button should show a spinner and be disabled
    And the "Decline" button should be disabled
    And only one accept request should be sent

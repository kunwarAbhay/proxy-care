# Screen: B7 My visits - Visits tab (User app)
# Source: proxy-care-ui-ux-state-for-api-design.md (PRD v2.3) §4 B7, §6 read models, §8 common UI states
# Upcoming = WAITING, ASSIGNED. Past = COMPLETED, SETTLED, CANCELLED.

@user-app @service-booking @B7
Feature: My visits - upcoming and past visits
  As a User
  I want one place that lists my upcoming and past visits
  So that I can check their status and open their details

  Background:
    Given I am logged in to the User app as "Rohan Mehta"
    And I have a linked patient "Kamla Mehta" with mobility "WHEELCHAIR"

  # ---------- Display ----------

  @smoke
  Scenario: Visits tab shows Upcoming and Past
    When I tap the "Visits" tab
    Then I should be on the "B7 My visits" screen
    And I should see the tabs "Upcoming" and "Past"
    And the "Upcoming" tab should be active

  @smoke
  Scenario: Upcoming card shows the date, patient, pickup time and hospital
    Given I have a booking "PC-2481" for "Kamla Mehta" on "2026-11-02" with pickup at "10:00 AM" at "Max Super Speciality Hospital, Saket" in state "WAITING"
    When I open the "Upcoming" tab of "B7 My visits"
    Then the card for "PC-2481" should show a date tile for "2 Nov"
    And the card for "PC-2481" should show the patient "Kamla Mehta"
    And the card for "PC-2481" should show the pickup time "10:00 AM" and the hospital
    And the card for "PC-2481" should show the status "Finding a caretaker"

  Scenario: Past card shows the purposes, hospital and total
    Given I have a settled booking "PC-2470" for "Kamla Mehta" with purposes "OPD, DIAGNOSTICS" and a visit total of "₹2,069"
    When I open the "Past" tab of "B7 My visits"
    Then the card for "PC-2470" should show the purposes, the hospital and the total "₹2,069"
    And the card for "PC-2470" should show the status "Completed · all settled"

  # ---------- Tabs and status chips ----------

  @happy-path
  Scenario Outline: Each booking state is listed on the right tab
    Given I have a booking "PC-2481" in state "<state>"
    When I open the "<tab>" tab of "B7 My visits"
    Then I should see the card for "PC-2481"

    Examples:
      | state     | tab      |
      | WAITING   | Upcoming |
      | ASSIGNED  | Upcoming |
      | SETTLED   | Past     |
      | CANCELLED | Past     |

  @negative
  Scenario Outline: Other booking states are not listed
    Given I have a booking "PC-2481" in state "<state>"
    When I open the "B7 My visits" screen
    Then I should not see the card for "PC-2481" on either tab

    Examples:
      | state           |
      | PAYMENT_PENDING |
      | IN_PROGRESS     |

  @happy-path
  Scenario Outline: Status chip reflects the booking
    Given I have a booking "PC-2481" in state "<state>"
    And the caretaker on booking "PC-2481" is "<caretaker>"
    And the refund on booking "PC-2481" is "<refund>"
    When I open the "B7 My visits" screen
    Then the card for "PC-2481" should show the status "<chip>"

    Examples:
      | state     | caretaker   | refund | chip                             |
      | WAITING   |             |        | Finding a caretaker              |
      | ASSIGNED  | Anita Verma |        | Caretaker assigned · Anita Verma |
      | SETTLED   | Anita Verma |        | Completed · all settled          |
      | CANCELLED |             | ₹1,150 | Cancelled · ₹1,150 refunded      |

  # ---------- Navigation ----------

  @smoke @navigation
  Scenario Outline: Opening a card goes to the screen for its state
    Given I have a booking "PC-2481" in state "<state>"
    And I am on the "B7 My visits" screen
    When I tap the card for "PC-2481"
    Then I should be on the "<screen>" screen for "PC-2481"

    Examples:
      | state     | screen               |
      | WAITING   | B5 Finding caretaker |
      | ASSIGNED  | B6 Caretaker assigned |
      | COMPLETED | F3 Visit statement   |
      | SETTLED   | F3 Visit statement   |
      | CANCELLED | F3 Visit statement   |

  # ---------- Realtime ----------

  @realtime
  Scenario: A booking moves within Upcoming when a caretaker accepts
    Given I have a booking "PC-2481" in state "WAITING"
    And I am on the "Upcoming" tab of "B7 My visits"
    When caretaker "Anita Verma" accepts booking "PC-2481"
    Then the card for "PC-2481" should show the status "Caretaker assigned · Anita Verma"

  # ---------- Access control ----------

  @access-control @security
  Scenario: Visits of other Users are not listed
    Given User "Priya Nair" has a booking "PC-2600" in state "WAITING"
    When I open the "B7 My visits" screen
    Then I should not see the card for "PC-2600" on either tab

  # ---------- Empty / loading / error ----------

  @empty-state
  Scenario Outline: Empty state per tab
    Given I have no <tab> visits
    When I open the "<tab>" tab of "B7 My visits"
    Then the "<tab>" tab should show an empty state

    Examples:
      | tab      |
      | Upcoming |
      | Past     |

  @ui-state
  Scenario: Skeleton while visits load
    Given the visits API responds slowly
    When I open the "B7 My visits" screen
    Then I should see skeleton visit cards

  @ui-state @error
  Scenario: Error state with retry
    Given the visits API returns a network error
    When I open the "B7 My visits" screen
    Then I should see an error with a "Retry" button
    When the visits API recovers
    And I tap "Retry"
    Then I should see the "Upcoming" tab content

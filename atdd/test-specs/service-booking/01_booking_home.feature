# Screen: B1 Home (User app)
# Source: proxy-care-ui-ux-state-for-api-design.md (PRD v2.3) §4 B1, §2 visit stage, §6 read models, §8 common UI states
# v2.3: no User wallet - no balance chip; bottom nav is Home, Visits, Payments, Family
# Home has an ongoing visit card and pending payment requests. Upcoming visits live on B7 (08_my_visits.feature).

@user-app @service-booking @B1
Feature: Booking home - select a family member, follow the ongoing visit and see pending payments
  As a User (sponsor)
  I want to pick a linked family member, see the ongoing visit and see what I still have to pay
  So that I can start a booking and stay on top of a visit from one screen

  Background:
    Given I am logged in to the User app as "Rohan Mehta"
    And I have the following linked patients:
      | name         | relation | age | sex | mobility   |
      | Kamla Mehta  | Mother   | 68  | F   | WHEELCHAIR |
      | Suresh Mehta | Father   | 72  | M   | AMBULATORY |

  # ---------- Display ----------

  @smoke
  Scenario: Home screen shows greeting, patients, ongoing visit, pending payments and navigation
    When I open the Home screen
    Then I should see a greeting containing "Rohan"
    And I should see the notifications icon
    And I should see the patient list with 2 patients
    And each patient card should show initials, name, relation, age, sex and mobility badge
    And I should see the "Ongoing visit" section
    And I should see the "Pending payment requests" section
    And I should not see an "Upcoming visits" section
    And I should see the bottom navigation with tabs "Home, Visits, Payments, Family"
    And the "Home" tab should be active


  # ---------- Happy path ----------

  @happy-path
  Scenario: Selecting a patient updates the booking CTA
    Given I am on the Home screen
    When I select the patient "Kamla Mehta"
    Then "Kamla Mehta" should be shown as selected
    And the primary button should read "Book Caretaker for Kamla"
    And the primary button should be enabled

  @happy-path
  Scenario: Patient list is single-select
    Given I am on the Home screen
    And I have selected the patient "Kamla Mehta"
    When I select the patient "Suresh Mehta"
    Then "Suresh Mehta" should be shown as selected
    And "Kamla Mehta" should not be shown as selected
    And the primary button should read "Book Caretaker for Suresh"

  @smoke @happy-path
  Scenario: Tapping Book Caretaker navigates to visit date & purposes
    Given I am on the Home screen
    And I have selected the patient "Kamla Mehta"
    When I tap "Book Caretaker for Kamla"
    Then I should be on the "B2 Visit date & purposes" screen
    And the selected patient header should show "Kamla Mehta" with mobility "Wheelchair"

  # ---------- Validation / disabled state ----------

  @negative
  Scenario: Booking CTA is disabled until a patient is selected
    Given I am on the Home screen
    And no patient is selected
    Then the "Book Caretaker" button should be disabled

  # ---------- Ongoing visit ----------

  @smoke @happy-path
  Scenario: Ongoing visit card shows the visit and its stage
    Given booking "PC-2481" for "Kamla Mehta" with caretaker "Anita Verma" at "Max Super Speciality Hospital, Saket" has stage "AT_HOSPITAL"
    When I open the Home screen
    Then the ongoing visit card should show the patient "Kamla Mehta"
    And the ongoing visit card should show the caretaker "Anita Verma"
    And the ongoing visit card should show the hospital "Max Super Speciality Hospital, Saket"
    And the ongoing visit card should show the stage badge "At hospital"

  @happy-path
  Scenario Outline: Stage badge text follows the visit stage
    Given booking "PC-2481" has stage "<stage>"
    When I open the Home screen
    Then the ongoing visit card should show the stage badge "<badge>"

    Examples:
      | stage                     | badge                  |
      | HEADING_TO_PICKUP         | Heading to pickup      |
      | PICKED_UP                 | Patient picked up      |
      | RIDE_TO_HOSPITAL          | Ride to hospital       |
      | OWN_TRANSPORT_TO_HOSPITAL | In transit to hospital |
      | AT_HOSPITAL               | At hospital            |
      | RIDE_HOME                 | Ride home              |
      | OWN_TRANSPORT_HOME        | In transit home        |
      | HANDOVER                  | Handover at home       |

  @realtime
  Scenario: Stage badge updates when the visit stage changes
    Given booking "PC-2481" has stage "PICKED_UP"
    And I am on the Home screen
    When the visit stage changes to "RIDE_TO_HOSPITAL"
    Then the ongoing visit card should show the stage badge "Ride to hospital" without a manual refresh

  @navigation
  Scenario: Ongoing visit card opens the timeline and live tracking
    Given booking "PC-2481" has stage "HEADING_TO_PICKUP"
    And I am on the Home screen
    When I tap the arrow on the ongoing visit card
    Then I should be on the "U2 Visit timeline" screen
    When I go back to the Home screen
    And I tap "Track caretaker live" on the ongoing visit card
    Then I should be on the "U1 Caretaker live location" screen

  @empty-state
  Scenario: No ongoing visit
    Given I have no ongoing visit
    When I open the Home screen
    Then the "Ongoing visit" section should show an empty state

  @negative
  Scenario: A booking still waiting for a caretaker is not an ongoing visit
    Given I have a booking "PC-2490" in state "WAITING"
    When I open the Home screen
    Then the "Ongoing visit" section should not show booking "PC-2490"

  # ---------- Pending payment requests ----------

  @smoke @happy-path
  Scenario: Pending payment requests are listed with a count
    Given booking "PC-2481" has the following payment requests:
      | type             | description                         | amount | status    |
      | HOSPITAL_BILL    | OPD registration + consultation fee | ₹500   | REQUESTED |
      | RIDE_TO_HOSPITAL | Ride to hospital                    | ₹320   | FAILED    |
    When I open the Home screen
    Then the "Pending payment requests" section should show the count badge "2"
    And each row should show the description, payee, requested-by, time and amount

  @negative
  Scenario Outline: Only unpaid requests are pending
    Given booking "PC-2481" has a hospital payment request for "₹500" with status "<status>"
    When I open the Home screen
    Then the "Pending payment requests" section should <listed> the "₹500" request

    Examples:
      | status    | listed   |
      | REQUESTED | show     |
      | FAILED    | show     |
      | PAID      | not show |

  @navigation
  Scenario Outline: A pending request opens its payment screen
    Given booking "PC-2481" has a "<type>" payment request with status "REQUESTED"
    And I am on the Home screen
    When I tap that request in the "Pending payment requests" section
    Then I should be on the "<screen>" screen

    Examples:
      | type             | screen                           |
      | HOSPITAL_BILL    | H5 Hospital payment request      |
      | RIDE_TO_HOSPITAL | U2b Ride payment request         |
      | RIDE_HOME        | U3b Ride home payment request    |

  @realtime
  Scenario: A new payment request appears without a manual refresh
    Given I have no pending payment requests
    And I am on the Home screen
    When the caretaker sends a hospital payment request for "₹500"
    Then the "Pending payment requests" section should show the count badge "1"

  @empty-state
  Scenario: No pending payment requests
    Given I have no pending payment requests
    When I open the Home screen
    Then the "Pending payment requests" section should show an empty state

  # ---------- Empty states ----------

  @empty-state
  Scenario: User has no linked family members
    Given I have no linked patients
    When I open the Home screen
    Then I should see an empty patient list prompt to add a family member
    And the "Book Caretaker" button should not be shown
    When I tap "Add family member"
    Then I should be on the "05 Add family member" screen

  @empty-state
  Scenario: Removed patient is not listed for booking
    Given the patient "Suresh Mehta" has been removed from my family
    When I open the Home screen
    Then I should see the patient list with 1 patient
    And I should not see "Suresh Mehta" in the patient list

  # ---------- Loading / error ----------

  @ui-state
  Scenario: Skeleton is shown while home data loads
    Given the home data API responds slowly
    When I open the Home screen
    Then I should see skeleton placeholders for the patient list, ongoing visit and pending payment requests
    When the home data API responds successfully
    Then the skeleton placeholders should be replaced by content

  @ui-state @error
  Scenario: Network error shows error state with retry
    Given the home data API returns a network error
    When I open the Home screen
    Then I should see an error message "Couldn't load your home. Check your connection."
    And I should see a "Retry" button
    When the home data API recovers
    And I tap "Retry"
    Then I should see the patient list with 2 patients

  # ---------- Navigation ----------

  @navigation
  Scenario Outline: Bottom navigation tabs
    Given I am on the Home screen
    When I tap the "<tab>" tab
    Then I should be on the "<screen>" screen

    Examples:
      | tab      | screen         |
      | Visits   | B7 My visits   |
      | Payments | B8 Payments    |
      | Family   | Family         |

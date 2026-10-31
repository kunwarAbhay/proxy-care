# Screen: B1 Home (User app)
# Source: proxy-care-api-context.md (PRD v2.3) §4 "Service booking" B1, §7 common UI states
# v2.3: no User wallet - no balance chip; bottom nav is Home, Visits, Payments, Family

@user-app @service-booking @B1
Feature: Booking home - select a family member and start a booking
  As a User (sponsor)
  I want to pick one of my linked family members from the home screen
  So that I can start booking a caretaker for their hospital visit

  Background:
    Given I am logged in to the User app as "Rohan Mehta"
    And I have the following linked patients:
      | name         | relation | age | sex | mobility   |
      | Kamla Mehta  | Mother   | 68  | F   | WHEELCHAIR |
      | Suresh Mehta | Father   | 72  | M   | AMBULATORY |

  # ---------- Display ----------

  @smoke
  Scenario: Home screen shows greeting, patients, visits and navigation
    When I open the Home screen
    Then I should see a greeting containing "Rohan"
    And I should see the notifications icon
    And I should see the patient list with 2 patients
    And each patient card should show initials, name, relation, age, sex and mobility badge
    And I should see the "Upcoming visits" section
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

  # ---------- Empty states ----------

  @empty-state
  Scenario: No visits booked yet
    Given I have no upcoming bookings
    When I open the Home screen
    Then the "Upcoming visits" section should show "No visits booked yet"

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

  # ---------- Upcoming visits ----------

  @happy-path
  Scenario Outline: Upcoming visit card reflects booking state
    Given I have a booking "<code>" for "Kamla Mehta" on "<date>" in state "<state>"
    When I open the Home screen
    Then the "Upcoming visits" section should show booking "<code>"
    And the booking card should show the status label "<label>"

    Examples:
      | code    | date       | state       | label              |
      | PC-2481 | 2026-11-02 | WAITING     | Finding caretaker  |
      | PC-2482 | 2026-11-03 | ASSIGNED    | Caretaker assigned |
      | PC-2483 | 2026-10-31 | IN_PROGRESS | Visit in progress  |

  @negative
  Scenario Outline: Inactive or unpaid bookings are not listed as upcoming
    Given I have a booking "<code>" in state "<state>"
    When I open the Home screen
    Then the "Upcoming visits" section should not show booking "<code>"

    Examples:
      | code    | state           |
      | PC-2490 | CANCELLED       |
      | PC-2491 | SETTLED         |
      | PC-2492 | PAYMENT_PENDING |

  # ---------- Loading / error ----------

  @ui-state
  Scenario: Skeleton is shown while home data loads
    Given the home data API responds slowly
    When I open the Home screen
    Then I should see skeleton placeholders for the patient list and upcoming visits
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
      | tab      | screen   |
      | Visits   | Visits   |
      | Payments | Payments |
      | Family   | Family   |

  @navigation
  Scenario: Tapping an upcoming visit opens its status screen
    Given I have a booking "PC-2481" in state "WAITING"
    And I am on the Home screen
    When I tap the upcoming visit "PC-2481"
    Then I should be on the "B5 Finding caretaker" screen for "PC-2481"

# Screen: B2 Visit date & purposes (User app)
# Source: proxy-care-api-context.md (PRD v2.3) §4 B2, §2 "Visit purpose" enum
# Each selected purpose becomes a Service at the hospital; one 3-hr block covers all of them.

@user-app @service-booking @B2
Feature: Choose visit date and visit purposes
  As a User
  I want to pick a date and one or more purposes for the hospital visit
  So that the caretaker knows when and why they are accompanying my family member

  Background:
    Given today is "2026-10-31"
    And I am logged in to the User app as "Rohan Mehta"
    And I have a linked patient "Kamla Mehta" with mobility "WHEELCHAIR"
    And I have started a booking for "Kamla Mehta" from the Home screen

  # ---------- Display ----------

  @smoke
  Scenario: Screen shows patient, date chips and purpose cards
    Then I should be on the "B2 Visit date & purposes" screen
    And I should see the selected patient "Kamla Mehta" with mobility badge "Wheelchair"
    And I should see 5 date chips starting from "Sat, 31 Oct"
    And I should see a "Pick another date" option
    And I should see the following purpose cards, each with an icon and an info "(i)" button:
      | purpose               |
      | OPD / Consultation    |
      | Diagnostics           |
      | Day Care Procedures   |
      | Admission / Discharge |
      | Emergency             |
    And no purpose should be selected
    And the "Next" button should be disabled

  # ---------- Happy path ----------

  @smoke @happy-path
  Scenario: Select a date and a single purpose and continue
    When I select the date chip "Mon, 2 Nov"
    And I select the purpose "OPD / Consultation"
    Then the "Next" button should be enabled
    When I tap "Next"
    Then I should be on the "B3 Hospital, pickup time & attachments" screen

  @happy-path
  Scenario: Select multiple purposes for one visit
    When I select the date chip "Mon, 2 Nov"
    And I select the purpose "OPD / Consultation"
    And I select the purpose "Diagnostics"
    Then both "OPD / Consultation" and "Diagnostics" should be shown as selected
    When I tap "Next"
    Then I should be on the "B3 Hospital, pickup time & attachments" screen


  @happy-path
  Scenario: Select all five purposes
    When I select the date chip "Sun, 1 Nov"
    And I select every purpose card
    Then 5 purposes should be shown as selected
    And the "Next" button should be enabled

  @happy-path
  Scenario: Pick a date from the date picker
    When I tap "Pick another date"
    Then a date picker should open
    When I choose "2026-11-20" in the date picker
    Then the date "Fri, 20 Nov" should be shown as selected
    And the date picker should close

  @happy-path
  Scenario: Today is a valid date
    When I select the date chip "Sat, 31 Oct"
    And I select the purpose "Emergency"
    Then the "Next" button should be enabled

  # ---------- Toggle behaviour ----------

  @ui-state
  Scenario: Tapping a selected purpose deselects it
    Given I have selected the purposes "OPD / Consultation, Diagnostics"
    When I tap the purpose "Diagnostics"
    Then "Diagnostics" should not be shown as selected
    And "OPD / Consultation" should be shown as selected

  @negative @ui-state
  Scenario: Deselecting the last purpose disables Next
    Given I have selected the date chip "Mon, 2 Nov"
    And I have selected the purposes "OPD / Consultation"
    When I tap the purpose "OPD / Consultation"
    Then no purpose should be selected
    And the "Next" button should be disabled

  @ui-state
  Scenario: Date selection is single-select
    Given I have selected the date chip "Mon, 2 Nov"
    When I select the date chip "Tue, 3 Nov"
    Then "Tue, 3 Nov" should be shown as selected
    And "Mon, 2 Nov" should not be shown as selected

  # ---------- Info tooltips ----------

  @ui-state
  Scenario Outline: Info tooltip explains each purpose
    When I tap the "(i)" button on the purpose "<purpose>"
    Then an info tooltip should open describing "<purpose>"
    And the purpose "<purpose>" should not become selected
    When I tap outside the tooltip
    Then the info tooltip should close

    Examples:
      | purpose               |
      | OPD / Consultation    |
      | Diagnostics           |
      | Day Care Procedures   |
      | Admission / Discharge |
      | Emergency             |

  @ui-state
  Scenario: Only one info tooltip is open at a time
    Given the info tooltip for "Diagnostics" is open
    When I tap the "(i)" button on the purpose "Emergency"
    Then the info tooltip for "Emergency" should be open
    And the info tooltip for "Diagnostics" should be closed

  # ---------- Validation ----------

  @negative
  Scenario: Next stays disabled with a date but no purpose
    When I select the date chip "Mon, 2 Nov"
    Then the "Next" button should be disabled

  @negative
  Scenario: Next stays disabled with a purpose but no date
    Given no date is selected by default
    When I select the purpose "Diagnostics"
    Then the "Next" button should be disabled

  @negative
  Scenario: Past dates cannot be chosen in the date picker
    When I tap "Pick another date"
    Then dates before "2026-10-31" should be disabled in the date picker

  # ---------- Navigation ----------

  @navigation
  Scenario: Back returns to Home with the patient still selected
    When I tap the back button
    Then I should be on the "B1 Home" screen
    And "Kamla Mehta" should be shown as selected

  @navigation
  Scenario: Selections are kept when returning from B3
    Given I have selected the date chip "Mon, 2 Nov"
    And I have selected the purposes "OPD / Consultation, Diagnostics"
    And I have tapped "Next"
    When I tap the back button on the "B3" screen
    Then I should be on the "B2 Visit date & purposes" screen
    And "Mon, 2 Nov" should be shown as selected
    And "OPD / Consultation" and "Diagnostics" should be shown as selected

  @navigation
  Scenario: Device back closes an open tooltip before leaving the screen
    Given the info tooltip for "Diagnostics" is open
    When I press the device back button
    Then the info tooltip should close
    And I should still be on the "B2 Visit date & purposes" screen

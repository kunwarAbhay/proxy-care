# Screens: P1 ongoing visit card, P3 My visits, P3a Visit details (Caretaker app)
# Source: proxy-care-ui-ux-state-for-api-design.md (PRD v2.3) §5 P1/P3/P3a, §2 visit stage, §6 read models, §7 realtime
# P3 has the tabs Upcoming and Past, with no Today tab. P3a is read-only.
# Every Attachments/Documents/Photos opens in-app only. Nobody can download it. 

@caretaker-app @service-booking @P1 @P3 @P3a
Feature: Caretaker ongoing visit, visit list and visit details
  As a Caretaker
  I want to resume the current visit and see the full details of the visits I accepted
  So that I am prepared and can always get back to the right step

  Background:
    Given today is "2026-10-31"
    And I am logged in to the Caretaker app as "Anita Verma" with KYC "APPROVED"
    And I am assigned to booking "PC-2481" for patient "Kamla Mehta", 68, with mobility "WHEELCHAIR"
    And booking "PC-2481" is for "2026-11-02" with pickup at "10:00 AM"
    And the hospital is "Max Super Speciality Hospital, Saket" with department "Cardiology" and purposes "OPD, DIAGNOSTICS"
    And the sponsoring user is "Rohan Mehta", relation "Son"
    And the instructions are "Doctor: Dr. A. Sharma. Carry old reports"
    And booking "PC-2481" has the attachment "prescription.jpg"

  # ---------- P1 ongoing visit card ----------

  @smoke
  Scenario: Ongoing visit card shows the visit and its stage
    Given booking "PC-2481" has stage "AT_HOSPITAL"
    When I open the "P1 Home" screen
    Then the ongoing visit card should show the patient "Kamla Mehta"
    And the ongoing visit card should show the hospital "Max Super Speciality Hospital, Saket"
    And the ongoing visit card should show the booking id "PC-2481"
    And the ongoing visit card should show the stage badge "At hospital"
    And I should see the resume arrow and "View full details"

  @smoke @navigation
  Scenario Outline: The resume arrow opens the screen for the current stage
    Given booking "PC-2481" has stage "<stage>"
    And I am on the "P1 Home" screen
    Then the ongoing visit card should show the stage badge "<badge>"
    When I tap the resume arrow on the ongoing visit card
    Then I should be on the "<screen>" screen

    Examples:
      | stage                     | badge                  | screen |
      | HEADING_TO_PICKUP         | Heading to pickup      | P4     |
      | PICKED_UP                 | Patient picked up      | P6     |
      | RIDE_TO_HOSPITAL          | Ride to hospital       | P8a    |
      | OWN_TRANSPORT_TO_HOSPITAL | In transit to hospital | P7b    |
      | AT_HOSPITAL               | At hospital            | H1     |
      | RIDE_HOME                 | Ride home              | D3a    |
      | OWN_TRANSPORT_HOME        | In transit home        | D2b    |
      | HANDOVER                  | Handover at home       | D5     |

  @navigation
  Scenario: View full details opens the visit details
    Given booking "PC-2481" has stage "AT_HOSPITAL"
    And I am on the "P1 Home" screen
    When I tap "View full details" on the ongoing visit card
    Then I should be on the "P3a Visit details" screen for "PC-2481"

  @navigation
  Scenario: After Visit Completed the card links to the payout status
    Given booking "PC-2481" has stage "COMPLETED_PAYOUT_PENDING"
    When I open the "P1 Home" screen
    Then the ongoing visit card should show the stage badge "Visit completed · payout pending"
    And I should not see the resume arrow
    When I tap "View payout status"
    Then I should be on the "F4 Visit earnings" screen

  @realtime
  Scenario: Stage change updates the badge and the resume target
    Given booking "PC-2481" has stage "PICKED_UP"
    And I am on the "P1 Home" screen
    When the visit stage changes to "RIDE_TO_HOSPITAL"
    Then the ongoing visit card should show the stage badge "Ride to hospital"
    When I tap the resume arrow on the ongoing visit card
    Then I should be on the "P8a" screen

  @navigation
  Scenario: Visits done opens the Past tab
    Given I am on the "P1 Home" screen
    When I tap "Visits done"
    Then I should be on the "P3 My visits" screen
    And the "Past" tab should be active

  # ---------- P3 My visits ----------

  @smoke
  Scenario: My visits has Upcoming and Past tabs only
    When I open the "P3 My visits" screen
    Then I should see the tabs "Upcoming" and "Past"
    And I should not see a "Today" tab

  @smoke
  Scenario: Upcoming card shows the visit summary
    When I open the "Upcoming" tab of "P3 My visits"
    Then the card for "PC-2481" should show the date "Mon, 2 Nov" and pickup time "10:00 AM"
    And the card for "PC-2481" should show the patient "Kamla Mehta, 68" and the mobility chip "Wheelchair"
    And the card for "PC-2481" should show the hospital and the purposes
    And the card for "PC-2481" should show "View full details"

  @navigation
  Scenario Outline: Start trip to pickup is offered only on the visit day
    Given today is "<today>"
    When I open the "Upcoming" tab of "P3 My visits"
    Then the card for "PC-2481" should <start> "Start trip to pickup"

    Examples:
      | today      | start    |
      | 2026-10-31 | not show |
      | 2026-11-01 | not show |
      | 2026-11-02 | show     |

  @smoke @navigation
  Scenario: Starting the trip from the visit day card
    Given today is "2026-11-02"
    And I am on the "Upcoming" tab of "P3 My visits"
    When I tap "Start trip to pickup" on the card for "PC-2481"
    Then I should be on the "P4 Start trip to pickup" screen

  @navigation
  Scenario: View full details from an upcoming card
    Given I am on the "Upcoming" tab of "P3 My visits"
    When I tap "View full details" on the card for "PC-2481"
    Then I should be on the "P3a Visit details" screen for "PC-2481"

  @happy-path
  Scenario Outline: Past card shows the earning and payout status
    Given I have a past visit "PC-2470" with an earning of "₹750" and earning status "<status>"
    When I open the "Past" tab of "P3 My visits"
    Then the card for "PC-2470" should show the date, patient, hospital, purpose and earning "₹750"
    And the card for "PC-2470" should show the payout chip "<chip>"

    Examples:
      | status       | chip           |
      | IN_WALLET    | In your wallet |

  @navigation
  Scenario: Opening a past card shows the visit earnings
    Given I have a past visit "PC-2470" with an earning of "₹750" and earning status "IN_WALLET"
    And I am on the "Past" tab of "P3 My visits"
    When I tap the card for "PC-2470"
    Then I should be on the "F4 Visit earnings" screen for "PC-2470"

  @empty-state
  Scenario Outline: Empty state per tab
    Given I have no <tab> visits
    When I open the "<tab>" tab of "P3 My visits"
    Then the "<tab>" tab should show an empty state

    Examples:
      | tab      |
      | Upcoming |
      | Past     |

  @ui-state
  Scenario: Skeleton while visits load
    Given the caretaker visits API responds slowly
    When I open the "P3 My visits" screen
    Then I should see skeleton visit cards

  @ui-state @error
  Scenario: Error state with retry
    Given the caretaker visits API returns a network error
    When I open the "P3 My visits" screen
    Then I should see an error with a "Retry" button

  # ---------- P3a Visit details ----------

  @smoke
  Scenario: Visit details show everything needed for the visit
    When I open the "P3a Visit details" screen for "PC-2481"
    Then I should see the booking id "PC-2481"
    And I should see the patient "Kamla Mehta", age "68" and mobility "Wheelchair"
    And I should see the date "Mon, 2 Nov" and pickup time "10:00 AM"
    And I should see the full pickup address
    And I should see the hospital name, address and department "Cardiology" with "Open in maps"
    And I should see the visit purposes "OPD / Consultation, Diagnostics"
    And I should see the instructions "Doctor: Dr. A. Sharma. Carry old reports"
    And I should see the attachment "prescription.jpg"
    And I should see the family contact "Rohan Mehta", relation "Son", with "Call"
    And I should see the caretaker earning "₹750" for "3 h × ₹250" with extra time in 30-minute steps

  Scenario: Visit details are read-only
    When I open the "P3a Visit details" screen for "PC-2481"
    And the only navigation action should be back

  @happy-path
  Scenario: Opening an attachment
    Given I am on the "P3a Visit details" screen for "PC-2481"
    When I tap the attachment "prescription.jpg"
    Then the file "prescription.jpg" should open

  @happy-path
  Scenario: Opening the hospital in maps
    Given I am on the "P3a Visit details" screen for "PC-2481"
    When I tap "Open in maps"
    Then the maps app should open at the hospital location

  @happy-path
  Scenario: Calling the family
    Given I am on the "P3a Visit details" screen for "PC-2481"
    When I tap "Call"
    Then the phone dialer should open with the family contact's number

  @access-control @security
  Scenario: Visit details do not expose the pickup code
    When I open the "P3a Visit details" screen for "PC-2481"
    Then I should not see the pickup code
    And the visit details API response should not contain the pickup code

  @access-control @security
  Scenario: An unassigned caretaker cannot open the visit details
    Given I am logged in to the Caretaker app as "Meena" with KYC "APPROVED"
    When I try to open the "P3a Visit details" screen for "PC-2481" by deep link
    Then I should see "You don't have access to this visit"
    And I should not see the pickup address, instructions or attachments

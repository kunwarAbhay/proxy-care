@hospital @user @H6
Feature: User follows hospital services and calls the caretaker (H6)
  As the User sponsoring a visit
  I want a read-only view of every booked service and its progress
  So that I know what is happening at the hospital and can join the consultation over WhatsApp

  Rules (PRD 3.4, context §2, §4):
    - H6 is read-only for the User: no Start / Complete controls.
    - Badges mirror the caretaker's service status in realtime.
    - "Phone/Video call Caretaker" opens WhatsApp with the caretaker's number. No in-app calling.
    - When all services are completed the User sees a banner leading to U3 (Coming home).

  Background:
    Given I am logged in to the User app as "Anita Sharma"
    And my booking "PC-2481" for patient "Kamla Devi" is in state "IN_PROGRESS"
    And booking "PC-2481" has purposes "OPD, DIAGNOSTICS"
    And caretaker "Ramesh Kumar" is assigned to booking "PC-2481"

  # ---------------------------------------------------------------------------
  # Entry
  # ---------------------------------------------------------------------------

  @smoke @navigation
  Scenario: Continuing after paying the ride to the hospital
    Given the "RIDE_TO_HOSPITAL" payment request is paid
    And I am on the "Ride payment request" screen (U2b) success state
    When I tap "Continue"
    Then I should be on the "Services status" screen (H6)

  @navigation
  Scenario: Reaching H6 when the caretaker used own transport
    Given the caretaker marked "I've reached the hospital" with mode "Family car"
    When I open booking "PC-2481" from the home screen
    Then I should be on the "Services status" screen (H6)
    And I should not have seen any ride payment request for leg "TO_HOSPITAL"

  # ---------------------------------------------------------------------------
  # Display
  # ---------------------------------------------------------------------------

  @smoke
  Scenario: All booked services are listed read-only
    When I open the "Services status" screen
    Then I should see 2 service rows
    And I should see the row "OPD / Consultation" with the badge "Pending"
    And I should see the row "Diagnostics" with the badge "Pending"
    And I should see the progress text "0 of 2 completed"
    And I should not see any "Start" or "Complete" button
    And I should see the "Phone/Video call Caretaker" button
    And I should see the "View visit timeline" link

  Scenario Outline: Badges and times reflect the service status
    Given the service "Diagnostics" has status "<status>"
    When I open the "Services status" screen
    Then the row "Diagnostics" should show the badge "<badge>"
    And the row "Diagnostics" should show <times>

    Examples:
      | status    | badge       | times                                   |
      | PENDING   | Pending     | no times                                |
      | STARTED   | In progress | the start time                          |
      | COMPLETED | Completed   | the start time and the completion time  |

  # ---------------------------------------------------------------------------
  # Realtime
  # ---------------------------------------------------------------------------

  @realtime
  Scenario: Badge updates when the caretaker starts a service
    Given I am on the "Services status" screen
    When the caretaker starts the service "OPD / Consultation"
    Then the row "OPD / Consultation" should show the badge "In progress" without a manual refresh
    And the visit timeline should include "OPD / Consultation started"

  @realtime
  Scenario: Completion notification for a single service
    Given the service "OPD / Consultation" has status "STARTED"
    And I am on the "Services status" screen
    When the caretaker completes the service "OPD / Consultation"
    Then the row "OPD / Consultation" should show the badge "Completed"
    And I should see the progress text "1 of 2 completed"
    And I should receive the notification "OPD / Consultation completed for Kamla Devi"

  @smoke @realtime @navigation
  Scenario: All services completed shows the coming-home banner
    Given the service "OPD / Consultation" has status "COMPLETED"
    And the service "Diagnostics" has status "STARTED"
    And I am on the "Services status" screen
    When the caretaker completes the service "Diagnostics"
    Then I should see the progress text "2 of 2 completed"
    And I should see the banner "All services done · Kamla is heading home"
    When I tap the banner
    Then I should be on the "Coming home" screen (U3)

  @realtime
  Scenario: Rollback on the caretaker side is not shown to the user
    Given I am on the "Services status" screen
    When the caretaker's "Start" on "Diagnostics" fails and is rolled back
    Then the row "Diagnostics" should still show the badge "Pending"

  @realtime
  Scenario: Realtime connection lost and restored
    Given I am on the "Services status" screen
    When the realtime connection drops
    Then I should see the hint "Reconnecting… statuses may be delayed"
    When the realtime connection is restored
    Then the service rows should refresh from the server
    And the hint should disappear

  Scenario: Pull to refresh fetches the latest statuses
    Given I am on the "Services status" screen
    When I pull to refresh
    Then I should see a refresh spinner
    And the service rows should show the latest statuses from the server

  @realtime @navigation
  Scenario: Hospital payment request banner on H6
    Given I am on the "Services status" screen
    When the caretaker sends a verified hospital bill for "₹500"
    Then I should see the banner "Hospital bill ₹500 · Approve & Pay"
    And tapping the banner should open the "Hospital payment request" screen (H5)

  Scenario: A QR mismatch on the caretaker side never reaches the user
    Given I am on the "Services status" screen
    When the caretaker scans a QR whose merchant is not the hospital
    Then I should not see any payment request banner
    And I should not receive any notification

  # ---------------------------------------------------------------------------
  # Phone / Video call caretaker (WhatsApp)
  # ---------------------------------------------------------------------------

  @smoke
  Scenario: Calling the caretaker opens WhatsApp
    Given WhatsApp is installed on my device
    And caretaker "Ramesh Kumar" has mobile "+919812345678"
    When I tap "Phone/Video call Caretaker"
    Then WhatsApp should open a chat with "+919812345678"
    And no in-app call screen should be shown

  @negative
  Scenario: WhatsApp is not installed
    Given WhatsApp is not installed on my device
    When I tap "Phone/Video call Caretaker"
    Then I should see the sheet "WhatsApp isn't installed"
    And I should see the options "Install WhatsApp" and "Call by phone"
    When I tap "Call by phone"
    Then the device dialer should open with the caretaker's number

  Scenario: Returning from WhatsApp keeps the screen up to date
    Given I left the app to WhatsApp from the "Services status" screen
    And the caretaker completed "OPD / Consultation" while I was away
    When I return to the User app
    Then I should be on the "Services status" screen
    And the row "OPD / Consultation" should show the badge "Completed"

  # ---------------------------------------------------------------------------
  # Loading / error / navigation
  # ---------------------------------------------------------------------------

  @ui-state
  Scenario: Skeleton while statuses load
    Given the services request is slow
    When I open the "Services status" screen
    Then I should see skeleton rows

  @ui-state @negative
  Scenario: Error state with retry
    Given the services request fails
    When I open the "Services status" screen
    Then I should see "Couldn't load services" with a "Retry" button
    And the "Phone/Video call Caretaker" button should still be available

  @navigation
  Scenario: View visit timeline and come back
    Given I am on the "Services status" screen
    When I tap "View visit timeline"
    Then I should be on the "Visit timeline" screen (U2)
    And the timeline should show events but no fares or charges
    When I press the device back button
    Then I should be on the "Services status" screen

  @navigation
  Scenario: Back from H6 goes to Home with the visit as ongoing
    Given I am on the "Services status" screen
    When I press the device back button
    Then I should be on the "Home" screen (B1)
    And I should see booking "PC-2481" as an ongoing visit
    When I tap the ongoing visit card
    Then I should be on the "Services status" screen

@hospital @caretaker @H1
Feature: Caretaker hospital services to-do list (H1)
  As an assigned Caretaker at the hospital
  I want a to-do card for every service the family booked
  So that I can mark each procedure as started and completed and keep the family informed

  Rules (PRD 3.4, context §2):
    - One Service card per selected booking purpose.
    - Service status: PENDING -> STARTED -> COMPLETED. Nothing in between.
    - "Start" is enabled only when PENDING; "Complete" only when STARTED.
    - A COMPLETED card is fully read-only.
    - "Leave hospital" is enabled only when every service is COMPLETED.
    - Visit stage is AT_HOSPITAL here; back from H1 goes to P1 Home, whose resume arrow reopens H1.

  Background:
    Given I am logged in to the Caretaker app as an approved caretaker "Ramesh Kumar"
    And I am assigned to booking "PC-2481" for patient "Kamla Devi"
    And booking "PC-2481" is in state "IN_PROGRESS"
    And the hospital for booking "PC-2481" is "Max Super Speciality Hospital, Saket"

  # ---------------------------------------------------------------------------
  # Entry into H1
  # ---------------------------------------------------------------------------

  @smoke @navigation
  Scenario: Arriving at the hospital after a paid ride to the hospital
    Given my ride to the hospital for booking "PC-2481" has status "TRIP_COMPLETED"
    And the ride payment request has status "PAID"
    And I am on the "Ride payment" screen (P9a)
    When I tap "Continue"
    Then I should be on the "Services to-do" screen (H1)
    And the timeline event "Reached hospital" should be recorded for booking "PC-2481"
    And the visit stage of booking "PC-2481" should be "AT_HOSPITAL"

  @navigation
  Scenario: Continue stays disabled on P9a until the family pays for the ride
    Given my ride to the hospital for booking "PC-2481" has status "TRIP_COMPLETED"
    And the ride payment request has status "REQUESTED"
    When I am on the "Ride payment" screen (P9a)
    Then the "Continue" button should be disabled
    And I should not be able to reach the "Services to-do" screen from P9a

  @navigation
  Scenario: Arriving at the hospital using own transport
    Given I chose "Family car" on the "Own transport" screen (P7b)
    When I tap "I've reached the hospital"
    Then I should be on the "Services to-do" screen (H1)
    And no ride payment request should exist for leg "TO_HOSPITAL"
    And the visit stage of booking "PC-2481" should be "AT_HOSPITAL"

  # ---------------------------------------------------------------------------
  # Display
  # ---------------------------------------------------------------------------

  @smoke
  Scenario: One card is shown per booked purpose, all pending
    Given booking "PC-2481" has purposes "OPD, DIAGNOSTICS"
    And the department is "Cardiology"
    When I open the "Services to-do" screen
    Then I should see 2 service cards
    And I should see a service card "OPD / Consultation" with detail "Cardiology"
    And I should see a service card "Diagnostics"
    And every service card should show the badge "Procedure pending"
    And I should see the progress text "0 of 2 completed"
    And I should see the "Scan QR" card
    And the "Leave hospital" button should be disabled

  Scenario Outline: Card count and labels match the selected purposes
    Given booking "PC-2481" has purposes "<purposes>"
    When I open the "Services to-do" screen
    Then I should see <count> service cards
    And I should see service cards titled "<titles>"
    And I should see the progress text "0 of <count> completed"

    Examples:
      | purposes                                                  | count | titles                                                                                  |
      | OPD                                                       | 1     | OPD / Consultation                                                                      |
      | DIAGNOSTICS                                               | 1     | Diagnostics                                                                             |
      | DAY_CARE                                                  | 1     | Day Care Procedure                                                                      |
      | ADMISSION_DISCHARGE                                       | 1     | Admission / Discharge                                                                   |
      | EMERGENCY                                                 | 1     | Emergency                                                                               |
      | OPD, DIAGNOSTICS                                          | 2     | OPD / Consultation, Diagnostics                                                         |
      | OPD, DIAGNOSTICS, DAY_CARE, ADMISSION_DISCHARGE, EMERGENCY| 5     | OPD / Consultation, Diagnostics, Day Care Procedure, Admission / Discharge, Emergency   |

  Scenario: Service card without a department shows no detail line
    Given booking "PC-2481" has purposes "DIAGNOSTICS"
    And booking "PC-2481" has no department
    When I open the "Services to-do" screen
    Then the service card "Diagnostics" should not show a detail line

  # ---------------------------------------------------------------------------
  # Start / Complete state machine
  # ---------------------------------------------------------------------------

  @smoke
  Scenario: Starting a pending service
    Given booking "PC-2481" has purposes "OPD, DIAGNOSTICS"
    And I am on the "Services to-do" screen
    When I tap "Start" on the service card "OPD / Consultation"
    Then the service card "OPD / Consultation" should show the badge "Procedure started"
    And the service card "OPD / Consultation" should show a start time
    And the "Start" button on "OPD / Consultation" should be disabled
    And the "Complete" button on "OPD / Consultation" should be enabled
    And the user should receive a "Service started" event for "OPD / Consultation"

  @smoke
  Scenario: Completing a started service
    Given booking "PC-2481" has purposes "OPD, DIAGNOSTICS"
    And the service "OPD / Consultation" has status "STARTED"
    And I am on the "Services to-do" screen
    When I tap "Complete" on the service card "OPD / Consultation"
    Then the service card "OPD / Consultation" should show the badge "Procedure completed"
    And the service card "OPD / Consultation" should show a start time and a completion time
    And the service card "OPD / Consultation" should be fully disabled
    And I should see the progress text "1 of 2 completed"
    And the user should receive a "Service completed" event for "OPD / Consultation"

  Scenario Outline: Button availability per service status
    Given the service "Diagnostics" has status "<status>"
    When I open the "Services to-do" screen
    Then the service card "Diagnostics" should show the badge "<badge>"
    And the "Start" button on "Diagnostics" should be <start>
    And the "Complete" button on "Diagnostics" should be <complete>

    Examples:
      | status    | badge               | start    | complete |
      | PENDING   | Procedure pending   | enabled  | disabled |
      | STARTED   | Procedure started   | disabled | enabled  |
      | COMPLETED | Procedure completed | disabled | disabled |

  @negative
  Scenario: A service cannot be completed before it is started
    Given the service "Diagnostics" has status "PENDING"
    And I am on the "Services to-do" screen
    When I try to tap "Complete" on the service card "Diagnostics"
    Then nothing should happen
    And the service "Diagnostics" should still have status "PENDING"

  @negative @api
  Scenario Outline: Server rejects an invalid status transition
    Given the service "Diagnostics" has status "<current>"
    When the app sends a "<action>" request for the service "Diagnostics"
    Then the server should reject the request with error "INVALID_SERVICE_TRANSITION"
    And the service "Diagnostics" should still have status "<current>"

    Examples:
      | current   | action   |
      | STARTED   | start    |
      | COMPLETED | start    |
      | PENDING   | complete |
      | COMPLETED | complete |

  Scenario: Services can be worked on in any order and in parallel
    Given booking "PC-2481" has purposes "OPD, DIAGNOSTICS"
    And I am on the "Services to-do" screen
    When I tap "Start" on the service card "Diagnostics"
    And I tap "Start" on the service card "OPD / Consultation"
    Then both service cards should show the badge "Procedure started"
    When I tap "Complete" on the service card "Diagnostics"
    Then the service card "Diagnostics" should show the badge "Procedure completed"
    And the service card "OPD / Consultation" should show the badge "Procedure started"

  Scenario: A double tap on Start sends a single transition
    Given the service "Diagnostics" has status "PENDING"
    And I am on the "Services to-do" screen
    When I double tap "Start" on the service card "Diagnostics"
    Then exactly one start request should be sent for "Diagnostics"
    And the service card "Diagnostics" should show the badge "Procedure started"

  @ui-state @negative
  Scenario: Start updates optimistically and rolls back if the server fails
    Given the service "Diagnostics" has status "PENDING"
    And the start request for "Diagnostics" will fail
    And I am on the "Services to-do" screen
    When I tap "Start" on the service card "Diagnostics"
    Then the service card "Diagnostics" should immediately show the badge "Procedure started"
    When the start request fails
    Then the service card "Diagnostics" should show the badge "Procedure pending"
    And the "Start" button on "Diagnostics" should be enabled
    And the service "Diagnostics" should still have status "PENDING"

  # ---------------------------------------------------------------------------
  # Leave hospital
  # ---------------------------------------------------------------------------

  @smoke @navigation
  Scenario: Leave hospital becomes available when all services are completed
    Given booking "PC-2481" has purposes "OPD, DIAGNOSTICS"
    And the service "OPD / Consultation" has status "COMPLETED"
    And the service "Diagnostics" has status "STARTED"
    And I am on the "Services to-do" screen
    When I tap "Complete" on the service card "Diagnostics"
    Then I should see the progress text "2 of 2 completed"
    And the "Leave hospital" button should be enabled
    And the user should receive an "All services completed" event
    When I tap "Leave hospital"
    Then I should be on the "Going home: book ride or skip" screen (D1)

  Scenario Outline: Leave hospital stays disabled while any service is not completed
    Given booking "PC-2481" has purposes "OPD, DIAGNOSTICS"
    And the service "OPD / Consultation" has status "<opd>"
    And the service "Diagnostics" has status "<diag>"
    When I open the "Services to-do" screen
    Then the "Leave hospital" button should be <leave>
    And I should see the progress text "<progress>"

    Examples:
      | opd       | diag      | leave    | progress          |
      | PENDING   | PENDING   | disabled | 0 of 2 completed  |
      | STARTED   | PENDING   | disabled | 0 of 2 completed  |
      | COMPLETED | PENDING   | disabled | 1 of 2 completed  |
      | COMPLETED | STARTED   | disabled | 1 of 2 completed  |
      | COMPLETED | COMPLETED | enabled  | 2 of 2 completed  |

  Scenario: Leaving the hospital with no bill scanned (pre-booked appointment)
    Given every service on booking "PC-2481" has status "COMPLETED"
    And no hospital bill exists for booking "PC-2481"
    When I tap "Leave hospital"
    Then I should be on the "Going home: book ride or skip" screen (D1)

  # ---------------------------------------------------------------------------
  # Scan QR entry
  # ---------------------------------------------------------------------------

  @navigation
  Scenario Outline: Scan QR card is available regardless of service progress
    Given the service "Diagnostics" has status "<status>"
    And I am on the "Services to-do" screen
    When I tap the "Scan QR" card
    Then I should be on the "Scan bill QR" screen (H2)

    Examples:
      | status    |
      | PENDING   |
      | STARTED   |
      | COMPLETED |

  Scenario: Existing bills are listed on the Scan QR card
    Given booking "PC-2481" has a hospital bill of "₹500" with status "PAYMENT_REQUESTED"
    And booking "PC-2481" has a hospital bill of "₹1,200" with status "PAID_BILL_PENDING"
    And booking "PC-2481" has a hospital bill of "₹300" with status "BILL_ATTACHED"
    When I open the "Services to-do" screen
    Then the "Scan QR" card should list 3 bills
    And the bill "₹500" should show the status "Payment requested"
    And the bill "₹1,200" should show the status "Paid · attach hospital bill"
    And the bill "₹300" should show the status "Hospital bill attached"
    When I tap the bill "₹500"
    Then I should be on the "Bill status" screen (H3) for that bill

  # ---------------------------------------------------------------------------
  # Loading, error, offline
  # ---------------------------------------------------------------------------

  @ui-state
  Scenario: Skeleton is shown while services load
    Given the services request is slow
    When I open the "Services to-do" screen
    Then I should see skeleton placeholders for the service cards
    And the "Leave hospital" button should be disabled
    When the services finish loading
    Then I should see the service cards

  @ui-state @negative
  Scenario: Error state with retry when services fail to load
    Given the services request fails
    When I open the "Services to-do" screen
    Then I should see an error state with the message "Couldn't load services"
    And I should see a "Retry" button
    When the services request succeeds
    And I tap "Retry"
    Then I should see the service cards

  @ui-state @negative
  Scenario: Offline banner and blocked actions
    Given I am on the "Services to-do" screen
    When the device goes offline
    Then I should see an offline banner
    And the "Start" and "Complete" buttons should be disabled
    When the device comes back online
    Then the offline banner should disappear
    And the service cards should refresh from the server

  @ui-state
  Scenario: State is preserved after the app is killed and reopened
    Given the service "Diagnostics" has status "STARTED"
    When I force close and reopen the Caretaker app
    Then I should be on the "Home" screen (P1)
    And the ongoing visit card should show booking "PC-2481" with the stage badge "At hospital"
    When I tap the resume arrow on the ongoing visit card
    Then I should be on the "Services to-do" screen (H1) for booking "PC-2481"
    And the service card "Diagnostics" should show the badge "Procedure started"

  # ---------------------------------------------------------------------------
  # Back behaviour
  # ---------------------------------------------------------------------------

  @navigation
  Scenario: Back from H1 goes to Home and the resume arrow returns to H1
    Given I reached the "Services to-do" screen from the "Ride payment" screen
    When I press the device back button
    Then I should not return to the "Ride payment" screen
    And I should be on the "Home" screen (P1)
    And the ongoing visit card should show booking "PC-2481" with the stage badge "At hospital"
    When I tap the resume arrow on the ongoing visit card
    Then I should be on the "Services to-do" screen (H1)

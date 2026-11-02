# End-to-end journeys across the Caretaker app and the User app, from Start trip to pickup to hospital arrival
# Source: proxy-care-ui-ux-state-for-api-design.md (PRD v2.3) §4, §5, §7; PRD 3.2, 3.3
# Screen-level detail and failure cases live in files 01-08. These scenarios need two signed-in sessions.
# Excluded from @smoke because of their run time. Each When here is a declarative step that may cover several screens.

@regression @pickup-and-ride @e2e @happy-path
Feature: Pickup and ride from start to finish
  As the Proxy Care platform
  I want the caretaker and user journeys to stay in step
  So that the patient reaches the hospital and every party sees the same status

  Background:
    Given today is "2026-11-02"
    And booking "PC-2481" for patient "Kamla Mehta" is sponsored by "Rohan Mehta"
    And caretaker "Anita Verma" is assigned to the booking
    And the booking is in state "ASSIGNED"
    And the pickup code is "4821"

  Scenario: The caretaker reaches the patient and the family follows
    When "Anita Verma" starts the trip to pickup
    Then "Rohan Mehta" should see the caretaker pin
    And the booking should have stage "HEADING_TO_PICKUP"
    When "Anita Verma" confirms arrival with the code "4821"
    Then the booking should be in state "IN_PROGRESS"
    And the booking should have stage "PICKED_UP"
    And "Rohan Mehta" should have the timeline event "Pickup OTP verified"

  Scenario: A partner ride is completed and paid
    Given the booking is in state "IN_PROGRESS" with stage "PICKED_UP"
    When "Anita Verma" books the ride option "Cab"
    Then the booking should have stage "RIDE_TO_HOSPITAL"
    When the ride partner completes the trip with the final fare "₹340"
    Then "Rohan Mehta" should have the timeline event "Trip Completed"
    When "Anita Verma" requests the ride fare
    Then "Rohan Mehta" should see the ride payment request banner without a refresh
    And the "Continue" button should be disabled for "Anita Verma"
    When "Rohan Mehta" pays the ride payment request
    Then "Anita Verma" should see the text "Rohan paid" without a refresh
    When "Anita Verma" continues to the hospital
    Then the booking should have stage "AT_HOSPITAL"

  Scenario: Own transport reaches the hospital with no ride charge
    Given the booking is in state "IN_PROGRESS" with stage "PICKED_UP"
    When "Anita Verma" chooses own transport
    Then "Rohan Mehta" should see the stage badge "In transit to hospital" without a refresh
    When "Anita Verma" reaches the hospital by "Family car"
    Then the booking should have stage "AT_HOSPITAL"
    And the booking should have 0 "RIDE_TO_HOSPITAL" payment requests

  Scenario: Changing from own transport to a partner ride
    Given the booking is in state "IN_PROGRESS" with stage "OWN_TRANSPORT_TO_HOSPITAL"
    When "Anita Verma" books the ride option "Cab XL" instead of own transport
    Then the booking should have stage "RIDE_TO_HOSPITAL"
    And "Rohan Mehta" should see the stage badge "Ride to hospital" without a refresh

  @negative
  Scenario: A wrong code holds back the journey until the right code is entered
    Given the booking has stage "HEADING_TO_PICKUP"
    When "Anita Verma" confirms arrival with the code "1234"
    Then the booking should be in state "ASSIGNED"
    And "Rohan Mehta" should not have the timeline event "Pickup OTP verified"
    When "Anita Verma" confirms arrival with the code "4821"
    Then the booking should be in state "IN_PROGRESS"

  @negative @payments
  Scenario: A failed ride payment keeps the caretaker waiting until the retry succeeds
    Given the booking is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And the booking has a "RIDE_TO_HOSPITAL" payment request for "₹340"
    When "Rohan Mehta" fails the ride payment on the gateway
    Then the "Continue" button should be disabled for "Anita Verma"
    When "Rohan Mehta" pays the ride payment request
    Then "Anita Verma" should see the text "Rohan paid" without a refresh
    And the "Continue" button should be enabled for "Anita Verma"

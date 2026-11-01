# End-to-end journeys across the Caretaker app and the User app, from Start trip to pickup to hospital arrival
# Source: proxy-care-ui-ux-state-for-api-design.md (PRD v2.3) §4, §5, §7; PRD 3.2, 3.3
# Screen-level detail and failure cases live in files 01-08.

@pickup-and-ride @e2e
Feature: Pickup and ride from start to finish
  As the Proxy Care platform
  I want the caretaker and user journeys to stay in step
  So that the patient reaches the hospital and every party sees the same status

  Background:
    Given today is "2026-11-02"
    And booking "PC-2481" for patient "Kamla Mehta" is in state "ASSIGNED" with pickup at "10:00 AM"
    And booking "PC-2481" is sponsored by user "Rohan Mehta"
    And caretaker "Anita Verma" is assigned to booking "PC-2481"
    And the pickup code for "PC-2481" is "4821"

  @smoke @happy-path
  Scenario: Pickup and a paid partner ride to the hospital
    # Trip to pickup
    Given "Anita Verma" is on the "P3 My visits" screen in the Caretaker app
    When "Anita Verma" taps "Start trip to pickup" on the card for "PC-2481"
    And "Anita Verma" turns on the "Reaching pickup location" toggle
    Then "Rohan Mehta" should see the caretaker pin on the "U1 Caretaker live location" screen
    And the visit stage of booking "PC-2481" should be "HEADING_TO_PICKUP"
    # Arrival
    When "Anita Verma" taps "I've arrived"
    And "Anita Verma" enters the code "4821" and taps "Confirm arrival"
    Then booking "PC-2481" should be in state "IN_PROGRESS"
    And the visit stage of booking "PC-2481" should be "PICKED_UP"
    And "Rohan Mehta" should see "Pickup OTP verified" on the "U2 Visit timeline" screen
    # Ride
    When "Anita Verma" chooses to book a ride
    And "Anita Verma" selects the ride option "Cab" and taps "Book"
    Then "Anita Verma" should be on the "P8a Ride status" screen
    And the visit stage of booking "PC-2481" should be "RIDE_TO_HOSPITAL"
    When the ride partner reports "RIDE_PARTNER_ASSIGNED", "RIDE_PARTNER_ARRIVED", "TRIP_STARTED" and "TRIP_COMPLETED"
    Then "Rohan Mehta" should see all 4 ride events on the "U2 Visit timeline" screen
    # Ride payment
    Given the final fare of the ride is "₹340"
    When "Anita Verma" taps "Request ₹340 from family"
    Then "Anita Verma" should be on the "P9a Ride payment" screen
    And the "Continue" button should be disabled for "Anita Verma"
    And "Rohan Mehta" should see a ride payment request banner
    When "Rohan Mehta" opens the "U2b Ride payment request" screen from the banner
    And "Rohan Mehta" taps "Approve & Pay ₹340" and completes the payment on the gateway
    Then "Rohan Mehta" should see the success message "₹340 paid"
    And "Anita Verma" should see "Rohan paid"
    # Hospital arrival
    When "Rohan Mehta" taps "Continue"
    Then "Rohan Mehta" should be on the "H6 Services status" screen
    When "Anita Verma" taps "Continue"
    Then "Anita Verma" should be on the "H1 Services to-do" screen
    And the visit stage of booking "PC-2481" should be "AT_HOSPITAL"

  @smoke @happy-path
  Scenario: Pickup and own transport to the hospital
    Given "Anita Verma" is on the "P5 Confirm arrival" screen in the Caretaker app
    When "Anita Verma" enters the code "4821" and taps "Confirm arrival"
    And "Anita Verma" chooses to skip the ride
    Then the visit stage of booking "PC-2481" should be "OWN_TRANSPORT_TO_HOSPITAL"
    And "Rohan Mehta" should see the stage badge "In transit to hospital" on the "B1 Home" screen
    When "Anita Verma" selects the mode "Family car" and taps "I've reached the hospital"
    Then "Anita Verma" should be on the "H1 Services to-do" screen
    And the visit stage of booking "PC-2481" should be "AT_HOSPITAL"
    And no "RIDE_TO_HOSPITAL" payment request should exist for booking "PC-2481"
    And "Rohan Mehta" should not have received a ride payment request

  @happy-path
  Scenario: Changing from own transport to a partner ride
    Given booking "PC-2481" is in state "IN_PROGRESS" with stage "OWN_TRANSPORT_TO_HOSPITAL"
    And "Anita Verma" is on the "P7b Own transport" screen in the Caretaker app
    When "Anita Verma" taps "Book a ride instead"
    And "Anita Verma" selects the ride option "Cab XL" and taps "Book"
    Then the visit stage of booking "PC-2481" should be "RIDE_TO_HOSPITAL"
    And "Rohan Mehta" should see the stage badge "Ride to hospital" on the "B1 Home" screen

  @negative
  Scenario: A wrong code holds back the whole journey until the right code is entered
    Given "Anita Verma" is on the "P5 Confirm arrival" screen in the Caretaker app
    When "Anita Verma" enters the code "1234" and taps "Confirm arrival"
    Then booking "PC-2481" should still be in state "ASSIGNED"
    And "Rohan Mehta" should still see the pickup code "4821" on the "U1 Caretaker live location" screen
    When "Anita Verma" calls the family and enters the code "4821" and taps "Confirm arrival"
    Then booking "PC-2481" should be in state "IN_PROGRESS"
    And "Anita Verma" should be on the "P6 Book ride or skip" screen

  @negative @payments
  Scenario: A failed ride payment keeps the caretaker waiting until the retry succeeds
    Given booking "PC-2481" is in state "IN_PROGRESS" with stage "RIDE_TO_HOSPITAL"
    And a "RIDE_TO_HOSPITAL" payment request for "₹340" exists for booking "PC-2481"
    And "Anita Verma" is on the "P9a Ride payment" screen in the Caretaker app
    When the payment by "Rohan Mehta" fails on the gateway
    Then the "Continue" button should be disabled for "Anita Verma"
    When "Anita Verma" taps "Remind family"
    And "Rohan Mehta" taps "Try again" and completes the payment on the gateway
    Then "Anita Verma" should see "Rohan paid"
    And the "Continue" button should be enabled for "Anita Verma"

# Screen: B6 Caretaker assigned - booking state ASSIGNED (User app)
# Source: proxy-care-api-context.md (PRD v2.3) §4 B6; Entity design (booking_secrets - pickup code readable by sponsor only)

@user-app @service-booking @B6
Feature: Caretaker assigned
  As a User
  I want to see who is coming, how to reach them and the pickup code
  So that I can trust the caretaker and hand over my family member safely

  Background:
    Given I am logged in to the User app as "Rohan Mehta"
    And booking "PC-2481" for "Kamla Mehta" is in state "ASSIGNED"
    And the assigned caretaker is:
      | field     | value              |
      | name      | Anita Verma        |
      | kyc       | APPROVED           |
      | skill     | Wheelchair trained |
      | rating    | 4.8                |
      | visits    | 126                |
      | languages | Hindi, English     |
    And the pickup code for "PC-2481" is "4821"

  @smoke
  Scenario: Assigned screen shows caretaker card, pickup code and progress
    When I open the "B6 Caretaker assigned" screen
    Then I should see the caretaker photo and name "Anita Verma"
    And I should see the badge "KYC verified"
    And I should see the skill "Wheelchair trained"
    And I should see rating "4.8" and "126 visits"
    And I should see languages "Hindi, English"
    And I should see the 4-digit pickup code "4821"
    And I should see a note that the code was also sent by SMS to the patient
    And the visit progress should highlight the step "Assigned"
    And I should see the actions "Call", "Message" and "Track visit live"

  @happy-path
  Scenario: Pickup code is sent by SMS to the patient's mobile
    When booking "PC-2481" becomes "ASSIGNED"
    Then an SMS containing the code "4821" should be sent to "+919812345678"


  @happy-path
  Scenario: Call the caretaker
    Given I am on the "B6 Caretaker assigned" screen
    When I tap "Call"
    Then the phone dialer should open with the caretaker's number

  @pending-design
  Scenario: Message the caretaker
    Given I am on the "B6 Caretaker assigned" screen
    When I tap "Message"
    Then a chat with "Anita Verma" should open

  @navigation
  Scenario: Track visit live opens the live location screen
    Given I am on the "B6 Caretaker assigned" screen
    When I tap "Track visit live"
    Then I should be on the "U1 Caretaker live location" screen

  @ui-state
  Scenario: Live tracking shows a waiting state before the caretaker starts the trip
    Given the caretaker has not toggled "Reaching pickup location"
    When I tap "Track visit live"
    Then I should see that live location will appear once the caretaker starts the trip

  # ---------- Access control ----------

  @access-control @security
  Scenario: Pickup code is never visible to the caretaker
    Given I am logged in to the Caretaker app as "Anita Verma"
    When I open booking "PC-2481" in "My visits"
    Then I should not see the pickup code
    And the booking details API response should not contain the pickup code

  @access-control @security
  Scenario: Another User cannot open this booking
    Given I am logged in to the User app as "Priya Nair"
    When I try to open booking "PC-2481" by deep link
    Then I should see "Visit not found"
    And no caretaker or patient details should be shown

  # ---------- Cancellation after assignment ----------

  @happy-path
  Scenario: Cancel an assigned booking - refund to bank
    Given the current time is "2026-10-31 19:50"
    And pickup is at "2026-11-02 10:00"
    And I am on the "B6 Caretaker assigned" screen
    When I open the overflow menu and tap "Cancel booking"
    And I confirm the cancellation
    Then the booking state should be "CANCELLED"
    And a refund of "₹1,150" should be created to my original payment method
    And caretaker "Anita Verma" should be notified that the visit was cancelled

  # ---------- Loading / error ----------

  @ui-state
  Scenario: Skeleton while caretaker details load
    Given the booking details API responds slowly
    When I open the "B6 Caretaker assigned" screen
    Then I should see a skeleton caretaker card

  @error
  Scenario: Error loading caretaker details
    Given the booking details API returns a network error
    When I open the "B6 Caretaker assigned" screen
    Then I should see an error with a "Retry" button

# Screens: B8 Payments, B9 Payment details (User app)
# Source: proxy-care-ui-ux-state-for-api-design.md (PRD v2.3) §4 B8/B9, §6 read models, §7 realtime, §8 common UI states
# The hospital bill path through these screens is also covered in
# hospital-appointment/03_user_hospital_payment_request.feature.

@user-app @service-booking @B8 @B9 @payments
Feature: Payments history and payment details
  As a User
  I want to see every payment I approved and paid, grouped by visit
  So that I can check what I paid for and keep the receipts and bills

  Background:
    Given I am logged in to the User app as "Rohan Mehta"
    And booking "PC-2481" for "Kamla Mehta" has a paid booking charge of "₹1,249"

  # ---------- B8 Payments ----------

  @smoke
  Scenario: Payments are grouped by visit and include the booking charge
    Given booking "PC-2481" has the following paid payment requests:
      | type             | description                         | amount |
      | RIDE_TO_HOSPITAL | Ride to hospital                    | ₹320   |
      | HOSPITAL_BILL    | OPD registration + consultation fee | ₹500   |
    When I tap the "Payments" tab
    Then I should be on the "B8 Payments" screen
    And I should see a group for booking "PC-2481" with the visit name and date
    And the group should list 3 payments including the booking charge "₹1,249"
    And each row should show a type icon, description, payee, time, amount and "Paid"

  Scenario: Payments from different visits are shown in separate groups
    Given booking "PC-2470" also has a paid booking charge of "₹1,099"
    When I open the "B8 Payments" screen
    Then I should see a group for booking "PC-2481"
    And I should see a group for booking "PC-2470"

  @negative
  Scenario Outline: Only paid requests are listed
    Given booking "PC-2481" has a hospital payment request for "₹500" with status "<status>"
    When I open the "B8 Payments" screen
    Then I should not see the "₹500" request

    Examples:
      | status    |
      | REQUESTED |
      | PAYING    |
      | FAILED    |
      | DISPUTED  |

  @realtime
  Scenario: A newly paid request appears in Payments
    Given booking "PC-2481" has a hospital payment request for "₹500" with status "PAYING"
    And I am on the "B8 Payments" screen
    When the gateway confirms the payment
    Then I should see the "₹500" request with "Paid"

  @access-control @security
  Scenario: Payments of other Users are not listed
    Given User "Priya Nair" has a paid booking charge on booking "PC-2600"
    When I open the "B8 Payments" screen
    Then I should not see a group for booking "PC-2600"

  @empty-state
  Scenario: No payments yet
    Given I have no paid payments
    When I open the "B8 Payments" screen
    Then I should see an empty state

  @ui-state
  Scenario: Skeleton while payments load
    Given the payments API responds slowly
    When I open the "B8 Payments" screen
    Then I should see skeleton payment rows

  @ui-state @error
  Scenario: Error state with retry
    Given the payments API returns a network error
    When I open the "B8 Payments" screen
    Then I should see an error with a "Retry" button

  # ---------- B9 Payment details ----------

  @smoke @navigation
  Scenario: Opening a payment shows its details
    Given I am on the "B8 Payments" screen
    When I tap the booking charge row for "PC-2481"
    Then I should be on the "B9 Payment details" screen
    And I should see the "Paid" chip, the description and the amount "₹1,249"

  @smoke
  Scenario: Booking charge shows its price breakdown
    When I open the "B9 Payment details" screen for the booking charge of "PC-2481"
    Then I should see the payment details

  Scenario Outline: Detail rows depend on the payment type
    Given a paid "<type>" payment request on booking "PC-2481"
    When I open the "B9 Payment details" screen for that request
    Then I should see the rows "paid to, requested by, paid on, method, transaction id, visit"
    And I should see the row "<extra_row>"
    And the "Bills" section should list "<bill>" when it is available

    Examples:
      | type             | extra_row | bill          |
      | HOSPITAL_BILL    | QR check  | hospital bill |
      | RIDE_TO_HOSPITAL | route     | trip receipt  |
      | RIDE_HOME        | route     | trip receipt  |

  Scenario: Caretaker fee shows the caretaker bill
    Given a paid "CARETAKER_FEE" payment request on booking "PC-2481"
    When I open the "B9 Payment details" screen for that request
    Then the "Bills" section should list "caretaker bill"

  @happy-path
  Scenario: Download a receipt
    Given I am on the "B9 Payment details" screen for the booking charge of "PC-2481"
    When I tap "Download receipt"
    Then I should receive the receipt as a PDF

  @error
  Scenario: Receipt download fails
    Given I am on the "B9 Payment details" screen for the booking charge of "PC-2481"
    And the receipt API returns a server error
    When I tap "Download receipt"
    Then I should see an error with a retry option

  @pending-design
  Scenario: Report a problem with a payment
    Given I am on the "B9 Payment details" screen for the booking charge of "PC-2481"
    When I tap "Report a problem with this payment"
    Then I should be able to report the problem

  @access-control @security
  Scenario: Another User cannot open a payment
    Given I am logged in to the User app as "Priya Nair"
    When I try to open the "B9 Payment details" screen for the booking charge of "PC-2481" by deep link
    Then I should not see the amount, method or transaction id

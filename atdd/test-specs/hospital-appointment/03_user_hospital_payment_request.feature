@hospital @user @H5 @B1 @B8 @B9 @payments
Feature: User approves and pays a hospital bill payment request (H5)
  As the User sponsoring a visit
  I want to review a verified hospital bill sent by the caretaker and pay it through the gateway
  So that the hospital desk is paid quickly and I stay in control of every charge

  Rules (context §2, §3, §4):
    - Payment request status: REQUESTED -> PAYING -> PAID / FAILED (retry); hospital bills also DISPUTED.
    - Hospital bill status: PAYMENT_REQUESTED -> PAID_BILL_PENDING (User paid) -> BILL_ATTACHED, or DISPUTED.
    - H5 shows the description the caretaker entered. There is no bill image at request time.
    - The hospital's bill is attached by the caretaker after payment and appears on B9.
    - Every charge goes through the third-party payment gateway (redirect, then return to the app).
    - There is no User wallet. Money goes to the Proxy Care account.
    - "This bill looks wrong" disputes the bill; nothing is paid.
    - Repeat taps on "Approve & Pay" must be idempotent.

  Background:
    Given I am logged in to the User app as "Anita Sharma"
    And my booking "PC-2481" for patient "Kamla Devi" is in state "IN_PROGRESS"
    And caretaker "Ramesh Kumar" is assigned to booking "PC-2481"
    And the hospital for booking "PC-2481" is "Max Super Speciality Hospital, Saket"

  # ---------------------------------------------------------------------------
  # Arrival on H5
  # ---------------------------------------------------------------------------

  @smoke @realtime @navigation
  Scenario: A hospital payment request banner appears on the services screen
    Given I am on the "Services status" screen (H6)
    When the caretaker sends a verified hospital bill for "₹500"
    Then I should see the banner "Hospital bill ₹500 · Approve & Pay"
    When I tap the banner
    Then I should be on the "Hospital payment request" screen (H5)

  @smoke @navigation
  Scenario: Opening the request from the pending list on Home
    Given a "HOSPITAL_BILL" payment request for "₹500" with description "OPD registration + consultation fee"
    When I open the "Home" screen (B1)
    Then the "Pending payment requests" list should show a count of 1
    And I should see the row "OPD registration + consultation fee" with the payee, requester, time and amount "₹500"
    When I tap the row
    Then I should be on the "Hospital payment request" screen (H5)

  @navigation
  Scenario: Opening the request from the unpaid requests screen
    Given I am on the "Unpaid requests" screen (F2) with an unpaid "₹500" hospital bill
    When I tap "Something looks wrong"
    Then I should be on the "Hospital payment request" screen (H5) for that bill

  @navigation
  Scenario: Opening the request from a push notification
    Given the app is in the background
    And I received the push notification "Ramesh sent a hospital bill of ₹500"
    When I tap the notification
    Then the User app should open on the "Hospital payment request" screen (H5) for that bill

  @navigation
  Scenario: Push notification for an already-paid bill opens the paid state
    Given the hospital bill for "₹500" has already been paid
    When I tap the old notification for that bill
    Then I should see the "Hospital payment request" screen in the "Paid" state
    And I should see a note that the caretaker will attach the hospital's bill
    And the "Approve & Pay" button should not be visible

  # ---------------------------------------------------------------------------
  # Display
  # ---------------------------------------------------------------------------

  @smoke
  Scenario: The request shows the verified bill details
    Given a "HOSPITAL_BILL" payment request for "₹500" with description "OPD registration + consultation fee"
    When I open the "Hospital payment request" screen
    Then I should see the amount "₹500"
    And I should see the status chip "Requested"
    And I should see the description "OPD registration + consultation fee"
    And I should see "Requested by Ramesh Kumar" with the request time
    And I should see "QR checks passed" with merchant "Max Super Speciality Hospital, Saket" and MCC "8062"
    And I should see the note "The hospital desk is waiting"
    And I should see the "Approve & Pay ₹500" button
    And I should see the "This bill looks wrong" link
    And I should not see a bill image

  # ---------------------------------------------------------------------------
  # Approve & Pay - gateway flow
  # ---------------------------------------------------------------------------

  @smoke
  Scenario: Paying a hospital bill successfully
    Given I am on the "Hospital payment request" screen for "₹500"
    When I tap "Approve & Pay ₹500"
    Then I should see the "Opening secure payment" sheet
    And the payment request status should be "PAYING"
    And I should be redirected to the payment gateway page for "₹500"
    When I complete the payment on the gateway
    And I return to the app
    Then I should see the success message "₹500 paid"
    And I should see a "Continue" button
    And the payment request status should be "PAID"
    And the hospital bill status should be "PAID_BILL_PENDING"
    And the caretaker should receive a "Hospital bill paid" event
    When I tap "Continue"
    Then I should be on the "Services status" screen (H6)
    And the "Pending payment requests" list on Home should not show the "₹500" bill

  @negative
  Scenario Outline: Gateway does not complete the payment
    Given I am on the "Hospital payment request" screen for "₹500"
    When I tap "Approve & Pay ₹500"
    And the gateway returns "<gateway_result>"
    Then I should see the message "<message>"
    And I should see a "<action>" button
    And the payment request status should be "<status>"
    And the hospital bill status should be "PAYMENT_REQUESTED"
    And the caretaker should not receive a "Hospital bill paid" event

    Examples:
      | gateway_result          | message                                   | action    | status    |
      | payment failed          | Payment failed. No money was taken.       | Try again | FAILED    |
      | cancelled by user       | Payment cancelled                         | Try again | REQUESTED |
      | bank declined           | Your bank declined the payment            | Try again | FAILED    |
      | session timed out       | Payment session expired                   | Try again | FAILED    |

  @negative
  Scenario: Retrying after a failed payment
    Given my last payment for the "₹500" hospital bill failed
    When I tap "Try again"
    Then a new gateway order should be created for the same payment request
    And I should be redirected to the payment gateway page for "₹500"
    When I complete the payment on the gateway
    And I return to the app
    Then I should see the success message "₹500 paid"

  @ui-state
  Scenario: App resumed mid-payment polls for the final status
    Given I tapped "Approve & Pay ₹500" and was redirected to the gateway
    And the app was killed while I was on the gateway
    When I reopen the User app
    Then I should see "Checking payment status…"
    When the gateway webhook confirms the payment
    Then I should see the success message "₹500 paid"

  @ui-state
  Scenario: Payment still pending after polling window
    Given I returned from the gateway
    And the gateway has not confirmed the payment within the polling window
    Then I should see "Payment is being confirmed. We'll notify you."
    And the "Approve & Pay" button should not be visible
    And I should not be able to start a second payment for this request

  @negative
  Scenario: Repeated taps on Approve & Pay create one gateway order
    Given I am on the "Hospital payment request" screen for "₹500"
    When I tap "Approve & Pay ₹500" 3 times quickly
    Then exactly one gateway order should be created for the payment request
    And the "Approve & Pay ₹500" button should show a loader and be disabled

  @negative
  Scenario: Gateway order creation fails before redirect
    Given the create gateway order request will fail
    And I am on the "Hospital payment request" screen for "₹500"
    When I tap "Approve & Pay ₹500"
    Then I should see the error toast "Couldn't start payment. Try again."
    And I should remain on the "Hospital payment request" screen
    And the payment request status should be "REQUESTED"

  @negative
  Scenario: Paying a request already paid on another device
    Given the "₹500" hospital bill was paid from my other device
    And I am still on the "Hospital payment request" screen on this device
    When I tap "Approve & Pay ₹500"
    Then no gateway order should be created
    And the screen should refresh to the "Paid" state

  # ---------------------------------------------------------------------------
  # Dispute - "This bill looks wrong"
  # ---------------------------------------------------------------------------

  @smoke
  Scenario: Disputing a hospital bill
    Given I am on the "Hospital payment request" screen for "₹500"
    When I tap "This bill looks wrong"
    Then I should see a confirmation sheet "Dispute this bill? Nothing will be paid."
    When I confirm the dispute
    Then I should see the status chip "Disputed"
    And the payment request status should be "DISPUTED"
    And the hospital bill status should be "DISPUTED"
    And no gateway order should be created
    And the caretaker should receive a "Hospital bill disputed" event
    And the "Approve & Pay" button should not be visible

  Scenario: Cancelling the dispute confirmation
    Given I am on the "Hospital payment request" screen for "₹500"
    When I tap "This bill looks wrong"
    And I dismiss the confirmation sheet
    Then the payment request status should be "REQUESTED"
    And the "Approve & Pay ₹500" button should be enabled

  @negative
  Scenario: Dispute is not available after the bill is paid
    Given the "₹500" hospital bill has status "PAID_BILL_PENDING"
    When I open the "Hospital payment request" screen
    Then I should not see the "This bill looks wrong" link

  @negative
  Scenario: Dispute is blocked while a payment is in progress
    Given the payment request status is "PAYING"
    When I open the "Hospital payment request" screen
    Then the "This bill looks wrong" link should be disabled

  # ---------------------------------------------------------------------------
  # State matrix
  # ---------------------------------------------------------------------------

  Scenario Outline: Screen controls per payment request status
    Given the hospital payment request has status "<status>"
    When I open the "Hospital payment request" screen
    Then I should see the status chip "<chip>"
    And the "Approve & Pay" button should be <pay>
    And the "This bill looks wrong" link should be <dispute>

    Examples:
      | status    | chip      | pay                     | dispute     |
      | REQUESTED | Requested | enabled                 | enabled     |
      | PAYING    | Paying    | shown with a loader     | disabled    |
      | FAILED    | Failed    | enabled as "Try again"  | enabled     |
      | PAID      | Paid      | hidden                  | hidden      |
      | DISPUTED  | Disputed  | hidden                  | hidden      |

  # ---------------------------------------------------------------------------
  # Multiple bills, loading, errors
  # ---------------------------------------------------------------------------

  Scenario: Multiple pending hospital bills are paid one by one
    Given there are 2 hospital payment requests "₹500" and "₹1,200" with status "REQUESTED"
    When I open the "Services status" screen (H6)
    Then I should see the banner "2 hospital bills waiting"
    When I tap the banner
    Then I should see a list of 2 pending hospital bills
    When I pay the "₹500" bill
    Then the banner should change to "1 hospital bill waiting"

  @ui-state
  Scenario: Loading skeleton while the request loads
    Given the payment request call is slow
    When I open the "Hospital payment request" screen
    Then I should see a skeleton for the amount and details
    And the "Approve & Pay" button should be disabled

  @ui-state @negative
  Scenario: Error state when the request cannot be loaded
    Given the payment request call fails
    When I open the "Hospital payment request" screen
    Then I should see "Couldn't load this request" with a "Retry" button

  @negative
  Scenario: Offline user cannot start payment
    Given the device is offline
    When I open the "Hospital payment request" screen
    Then I should see an offline banner
    And the "Approve & Pay" button should be disabled

  # ---------------------------------------------------------------------------
  # Payment history and the attached hospital bill (B8, B9)
  # ---------------------------------------------------------------------------

  @smoke
  Scenario: A paid hospital bill appears in Payments
    Given I paid the "₹500" hospital bill with description "OPD registration + consultation fee"
    When I open the "Payments" tab (B8)
    Then I should see the row "OPD registration + consultation fee" with amount "₹500" and "Paid" under booking "PC-2481"
    When I tap the row
    Then I should be on the "Payment details" screen (B9)
    And I should see the paid to, QR check, requested by, paid on, method and transaction id rows

  Scenario: The Bills section is empty until the caretaker attaches the hospital's bill
    Given the "₹500" hospital bill has status "PAID_BILL_PENDING"
    When I open the "Payment details" screen (B9) for that bill
    Then I should not see a hospital bill in the "Bills" section

  @realtime
  Scenario: The attached hospital bill appears on Payment details
    Given the "₹500" hospital bill has status "PAID_BILL_PENDING"
    And I am on the "Payment details" screen (B9) for that bill
    When the caretaker attaches the hospital's bill
    Then I should see the hospital bill in the "Bills" section

  Scenario: Unpaid requests are not listed in Payments
    Given a "HOSPITAL_BILL" payment request for "₹500" with status "REQUESTED"
    When I open the "Payments" tab (B8)
    Then I should not see the "₹500" hospital bill

  # ---------------------------------------------------------------------------
  # Navigation & back behaviour
  # ---------------------------------------------------------------------------

  @navigation
  Scenario: Back from an unpaid request keeps it pending
    Given I am on the "Hospital payment request" screen for "₹500"
    When I press the device back button
    Then I should be on the "Services status" screen (H6)
    And I should still see the banner "Hospital bill ₹500 · Approve & Pay"

  @navigation
  Scenario: Back after a successful payment does not reopen the gateway
    Given I have just paid the "₹500" hospital bill
    When I press the device back button
    Then I should be on the "Services status" screen (H6)
    And I should not be returned to the payment gateway page

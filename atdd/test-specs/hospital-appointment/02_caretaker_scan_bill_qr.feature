@hospital @caretaker @H2 @H3
Feature: Caretaker scans a hospital bill QR and requests payment from the family (H2, H3)
  As an assigned Caretaker at the hospital desk
  I want to scan the bill's UPI QR code
  So that the family receives a verified payment request and I never pay with my own money

  Rules (PRD 3.4, context §2):
    - QR checks: QR readable (UPI) · merchant name matches hospital · MCC is a hospital MCC (e.g. 8062).
    - All three checks pass -> bill status PAYMENT_REQUESTED, a HOSPITAL_BILL payment request is sent to the User.
    - Any check fails -> bill status QR_MISMATCH, no payment request is sent.
    - Bill status then moves to PAID or DISPUTED based on the User's action.

  Background:
    Given I am logged in to the Caretaker app as an approved caretaker "Ramesh Kumar"
    And I am assigned to booking "PC-2481" in state "IN_PROGRESS"
    And the hospital for booking "PC-2481" is "Max Super Speciality Hospital, Saket"
    And the sponsoring user for booking "PC-2481" is "Anita Sharma"
    And I am on the "Services to-do" screen (H1)

  # ---------------------------------------------------------------------------
  # H2 Scan bill QR - camera
  # ---------------------------------------------------------------------------

  @smoke
  Scenario: Opening the scanner shows the camera viewfinder
    Given camera permission is granted
    When I tap the "Scan QR" card
    Then I should be on the "Scan bill QR" screen (H2)
    And I should see the camera viewfinder with a scan frame
    And I should see a "Torch" toggle

  Scenario: Toggling the torch
    Given I am on the "Scan bill QR" screen
    When I tap the "Torch" toggle
    Then the device torch should turn on
    And the "Torch" toggle should show the on state
    When I tap the "Torch" toggle
    Then the device torch should turn off

  @negative
  Scenario: Camera permission is requested on first use
    Given camera permission has not been requested yet
    When I tap the "Scan QR" card
    Then I should see the system camera permission prompt
    When I allow camera access
    Then I should see the camera viewfinder

  @negative
  Scenario: Camera permission denied falls back to photo upload
    Given camera permission is denied
    When I tap the "Scan QR" card
    And I should see the message "Camera access is off"
    And I tap the "Scan QR" card
    Then I should see the system camera permission prompt


  Scenario: Device without torch hides the torch toggle
    Given the device has no flash
    When I open the "Scan bill QR" screen
    Then I should not see the "Torch" toggle

  @navigation
  Scenario: Back from the scanner returns to the services list
    Given I am on the "Scan bill QR" screen
    When I press the device back button
    Then I should be on the "Services to-do" screen (H1)
    And no hospital bill should be created for booking "PC-2481"

  # ---------------------------------------------------------------------------
  # Capture & verification - happy path
  # ---------------------------------------------------------------------------

  @smoke
  Scenario: Scanning a valid hospital QR sends a payment request to the family
    Given I am on the "Scan bill QR" screen
    And the bill QR encodes "upi://pay?pa=maxsaket@hdfcbank&pn=Max Super Speciality Hospital Saket&mc=8062&am=500.00"
    When I capture the QR code
    Then I should see a "Verifying bill" loader
    And I should be on the "Bill status" screen (H3)
    And I should see the amount "₹500"
    And I should see the check "QR readable" as passed
    And I should see the check "Merchant name matches hospital" as passed
    And I should see the check "MCC is hospital (8062)" as passed
    And I should see the status banner "Payment requested from Anita"
    And a payment request of type "HOSPITAL_BILL" for "₹500" should exist with status "REQUESTED"
    And the hospital bill should have status "PAYMENT_REQUESTED"
    And the user "Anita Sharma" should receive a "Hospital payment request" notification

@smoke
  Scenario: Scanning a valid hospital QR and ask caretaker to input amount
    Given I am on the "Scan bill QR" screen
    And the bill QR encodes "upi://pay?pa=maxsaket@hdfcbank&pn=Max Super Speciality Hospital Saket&mc=8062"
    When I capture the QR code
    And I should see a "Verifying bill" loader
    And ask the user to input the amount.
    Then I should be on the "Bill status" screen (H3)

  Scenario: Bill description is captured with the bill
    Given I am on the "Scan bill QR" screen
    And the bill QR is valid for "₹500"
    When I capture the QR code
    And I enter the description "OPD registration + consultation fee"
    And I attach a photo of the bill
    And I tap "Send to family"
    Then the payment request should show the description "OPD registration + consultation fee"
    And the payment request should include the bill image

  # ---------------------------------------------------------------------------
  # QR mismatch / validation
  # ---------------------------------------------------------------------------

  @negative
  Scenario Outline: A failed QR check blocks the payment request
    Given I am on the "Scan bill QR" screen
    And the bill QR has <condition>
    When I capture the QR code
    Then I should be on the "Bill status" screen (H3)
    And I should see the check "<failed_check>" as failed
    And I should see the status banner "QR mismatch: no request sent"
    And the hospital bill should have status "QR_MISMATCH"
    And no payment request should be created for the bill
    And the user should not receive any notification
    And I should see a "Scan again" button

    Examples:
      | condition                                                    | failed_check                   |
      | merchant name "Apollo Pharmacy Saket"                        | Merchant name matches hospital |
      | MCC "5912" (drug store)                                      | MCC is hospital                |
      | MCC "5411" (grocery)                                         | MCC is hospital                |
      | no MCC field                                                 | MCC is hospital                |
      | merchant name "Ramesh Kumar" and no MCC (personal UPI)       | Merchant name matches hospital |

  @negative
  Scenario Outline: Unreadable or non-UPI codes are rejected on the scanner
    Given I am on the "Scan bill QR" screen
    When I capture a code that is <code>
    Then I should see the error "<message>"
    And I should remain on the "Scan bill QR" screen
    And no hospital bill should be created

    Examples:
      | code                                   | message                                         |
      | a website URL "https://maxhealthcare.in" | This isn't a UPI payment QR. Scan the bill QR. |
      | a plain text code                      | This isn't a UPI payment QR. Scan the bill QR.  |
      | a barcode (EAN-13)                     | This isn't a UPI payment QR. Scan the bill QR.  |
      | blurred and unreadable                 | Couldn't read the QR. Hold steady and try again. |

  @negative
  Scenario Outline: Amount validation on the scanned QR
    Given I am on the "Scan bill QR" screen
    And the bill QR is from the hospital with amount "<amount>"
    When I capture the QR code
    Then <outcome>

    Examples:
      | amount  | outcome                                                                         |
      | 0.00    | I should see the error "Bill amount must be more than ₹0"                       |
      | -100.00 | I should see the error "Bill amount must be more than ₹0"                       |
      | abc     | I should see the error "Couldn't read the bill amount"                          |
      | 500.00  | I should see the amount "₹500" on the "Bill status" screen                      |
      | 1.00    | I should see the amount "₹1" on the "Bill status" screen                        |

  @negative
  Scenario: Dynamic QR without an amount requires manual entry
    Given I am on the "Scan bill QR" screen
    And the bill QR is from the hospital with no amount
    When I capture the QR code
    Then I should see an "Enter bill amount" field
    And the "Send to family" button should be disabled
    When I enter "650" in the "Enter bill amount" field
    Then the "Send to family" button should be enabled

  @negative
  Scenario Outline: Description field validation
    Given I captured a valid hospital QR for "₹500"
    When I enter "<description>" as the description
    Then <outcome>

    Examples:
      | description                       | outcome                                                                  |
      |                                   | the "Send to family" button should be disabled                           |
      | OPD fee                           | the "Send to family" button should be enabled                            |
      | [STRING_OF_201_CHARS]             | I should see the inline error "Keep the description under 200 characters" |

  @negative
  Scenario: Upload photo with an image that has no QR
    Given I am on the "Scan bill QR" screen
    When I tap "Upload photo"
    And I select a gallery image with no QR code
    Then I should see the error "No QR code found in this photo"
    And I should remain on the "Scan bill QR" screen

  @negative
  Scenario: Verification service fails
    Given I am on the "Scan bill QR" screen
    And the bill verification request will fail
    When I capture a valid hospital QR
    Then I should see the error toast "Couldn't verify the bill. Try again."
    And I should see a "Retry" action
    And no payment request should be created

  @negative
  Scenario: Same QR scanned twice creates only one request
    Given a hospital bill for "₹500" with the same QR payload already has status "PAYMENT_REQUESTED"
    And I am on the "Scan bill QR" screen
    When I capture the same QR code again
    Then I should see the message "This bill was already sent to the family"
    And I should be on the "Bill status" screen for the existing bill
    And only one "HOSPITAL_BILL" payment request should exist for that QR payload

  # ---------------------------------------------------------------------------
  # H3 Bill status - realtime updates and actions
  # ---------------------------------------------------------------------------

  @smoke @realtime
  Scenario: Bill status updates when the family pays
    Given I am on the "Bill status" screen for a "₹500" bill with status "PAYMENT_REQUESTED"
    When the user "Anita Sharma" pays the hospital payment request
    Then the status banner should change to "Anita paid ₹500"
    And the hospital bill should have status "PAID"
    And I should see a "View receipt" button
    And the "Remind family" button should not be visible

  @realtime
  Scenario: Bill status updates when the family disputes the bill
    Given I am on the "Bill status" screen for a "₹500" bill with status "PAYMENT_REQUESTED"
    When the user "Anita Sharma" marks the bill as "This bill looks wrong"
    Then the status banner should change to "Anita disputed this bill"
    And the hospital bill should have status "DISPUTED"
    And I should see the guidance "Check the bill with the desk and scan again if needed"
    And I should see a "Scan again" button

  @realtime
  Scenario: A failed payment attempt keeps the request open
    Given I am on the "Bill status" screen for a "₹500" bill with status "PAYMENT_REQUESTED"
    When the user's gateway payment for the bill fails
    Then the status banner should still show "Payment requested from Anita"
    And the "Remind family" button should be visible

  Scenario Outline: Actions available per bill status
    Given I am on the "Bill status" screen for a bill with status "<status>"
    Then I should see the buttons "<visible>"
    And I should not see the buttons "<hidden>"

    Examples:
      | status            | visible                                  | hidden                        |
      | PAYMENT_REQUESTED | Back to services, Remind family          | View receipt                  |
      | PAID              | Back to services, View receipt           | Remind family, Scan again     |
      | QR_MISMATCH       | Back to services, Scan again             | Remind family, View receipt   |
      | DISPUTED          | Back to services, Scan again             | Remind family, View receipt   |

  Scenario: Reminding the family about an unpaid bill
    Given I am on the "Bill status" screen for a "₹500" bill with status "PAYMENT_REQUESTED"
    When I tap "Remind family"
    Then I should see the toast "Reminder sent to Anita"
    And the user "Anita Sharma" should receive a reminder notification for the "₹500" bill
    And the "Remind family" button should be disabled for 2 minutes

  @negative
  Scenario: Remind family is rate limited
    Given I sent a reminder for the "₹500" bill less than 2 minutes ago
    When I open the "Bill status" screen for that bill
    Then the "Remind family" button should be disabled
    And I should see the hint "You can remind again in a moment"

  @navigation
  Scenario: Scan again from a mismatched bill opens the scanner
    Given I am on the "Bill status" screen for a bill with status "QR_MISMATCH"
    When I tap "Scan again"
    Then I should be on the "Scan bill QR" screen (H2)

  @navigation
  Scenario: Back to services returns to H1 and shows the bill on the Scan QR card
    Given I am on the "Bill status" screen for a "₹500" bill with status "PAYMENT_REQUESTED"
    When I tap "Back to services"
    Then I should be on the "Services to-do" screen (H1)
    And the "Scan QR" card should list the bill "₹500" with status "Payment requested"

  Scenario: Services can continue while a bill is unpaid
    Given a "₹500" hospital bill has status "PAYMENT_REQUESTED"
    And I am on the "Services to-do" screen
    Then the "Start" buttons on pending services should be enabled

  Scenario: Leaving the hospital is allowed with an unpaid bill, but earnings go on hold later
    Given a "₹500" hospital bill has status "PAYMENT_REQUESTED"
    And every service on booking "PC-2481" has status "COMPLETED"
    When I open the "Services to-do" screen
    Then the "Leave hospital" button should be enabled
    And I should see the warning "1 bill still unpaid by family"

  Scenario: Caretaker never sees a pay option
    Given I am on the "Bill status" screen for a "₹500" bill with status "PAYMENT_REQUESTED"
    Then I should not see any "Pay" button
    And I should see the note "Your family pays the hospital. Don't pay from your own money."

# Screen: B3 Hospital, pickup time & attachments (User app)
# Source: proxy-care-ui-ux-state-for-api-design.md (PRD v2.3) §4 B3, §8 uploads
# v2.3: the pre-booked flag and appointment time are gone. The User sets a required
#       pickup time = when the caretaker arrives at the patient's home.
# The doctor field is gone: doctor name and appointment time go in the instructions.
# Pickup time uses an M3 time picker dialog. The hospital map shows no distance.

@user-app @service-booking @B3
Feature: Hospital, pickup time and attachments
  As a User
  I want to tell the caretaker which hospital to go to, when to pick up, and share documents
  So that the visit runs smoothly

  Background:
    Given today is "2026-10-31"
    And I am logged in to the User app as "Rohan Mehta"
    And I have a linked patient "Kamla Mehta" with mobility "WHEELCHAIR"
    And I have chosen date "2026-11-02" and purposes "OPD" on the "B2" screen
    And I am on the "B3 Hospital, pickup time & attachments" screen

  # ---------- Display ----------

  @smoke
  Scenario: Screen shows hospital, department, pickup time, instructions and attachments
    Then I should see the fields "Hospital", "Department", "Pickup time", "Instructions for caretaker" and "Attachments"
    And "Hospital" and "Pickup time" should be marked as required
    And the pickup time field should explain that the caretaker arrives at the patient's home at this time
    And the "Next" button should be disabled

  # ---------- Happy paths ----------

  @smoke @happy-path
  Scenario: Fill all fields and continue
    When I search for the hospital "Max Saket"
    And I select "Max Super Speciality Hospital, Saket" from the results
    Then I should see a map pin and the hospital address
    When I select the department "Cardiology"
    And I select the pickup time "09:30 AM" in the time picker
    Then the "Next" button should be enabled
    When I tap "Next"
    Then I should be on the "B4 Review · Confirm & Pay" screen

  @happy-path
  Scenario: Department is optional
    When I select the hospital "AIIMS, Ansari Nagar"
    And I select the pickup time "09:30 AM" in the time picker
    And I leave the department empty
    Then the "Next" button should be enabled



  # ---------- Instructions ----------

  @happy-path
  Scenario Outline: Instructions via quick chips and free text
    When I tap the quick chip "<chip>"
    And I type "Use the east gate" in the instructions field
    Then the instructions field should contain "<chip>"
    And the instructions field should contain "Use the east gate"

    Examples:
      | chip                      |
      | Carry old reports         |
      | Reach hospital by 10:30 AM |

  @ui-state
  Scenario: Tapping a quick chip twice does not duplicate the text
    When I tap the quick chip "Carry old reports"
    And the "Carry old reports" chip will be shown as selected
    And I tap the quick chip "Carry old reports" again
    Then the "Carry old reports" chip should not be shown as selected

    
  # ---------- Hospital search states ----------

  @ui-state
  Scenario: Hospital search shows a loading state
    Given the hospital search API responds slowly
    When I search for the hospital "Fortis"
    Then I should see a loading indicator in the results list

  @empty-state
  Scenario: Hospital search returns no results
    When I search for the hospital "zzzz-nonexistent"
    Then I should see the empty state "No hospitals found"
    And I should see a hint to search by name or area

  @error
  Scenario: Hospital search fails
    Given the hospital search API returns a server error
    When I search for the hospital "Fortis"
    Then I should see an error message with a "Retry" option

  @ui-state
  Scenario: Changing the selected hospital
    Given I have selected the hospital "AIIMS, Ansari Nagar"
    When I tap "Change" on the hospital card
    And I select the hospital "Safdarjung Hospital"
    Then the hospital card should show "Safdarjung Hospital"

  # ---------- Required field validation ----------

  @negative
  Scenario Outline: Next is disabled until hospital and pickup time are set
    Given the hospital is "<hospital>"
    And the pickup time is "<pickup>"
    Then the "Next" button should be "<next_state>"

    Examples:
      | hospital            | pickup   | next_state |
      |                     |          | disabled   |
      | AIIMS, Ansari Nagar |          | disabled   |
      |                     | 09:30 AM | disabled   |
      | AIIMS, Ansari Nagar | 09:30 AM | enabled    |

  @negative
  Scenario: Pickup time in the past is not allowed for a same-day visit
    Given I went back and chose date "2026-10-31" on the "B2" screen
    And the current time is "19:50"
    When I select the pickup time "06:00 PM" in the time picker
    Then I should see the inline error "Pickup time has already passed"
    And the "Next" button should be disabled

  @negative
  Scenario: Changing the date to today clears a pickup time that is now in the past
    Given I have selected the pickup time "09:30 AM"
    And the current time is "19:50"
    When I go back and change the date to "2026-10-31"
    And I return to the "B3" screen
    Then the pickup time should be empty
    And the "Next" button should be disabled

  @negative
  Scenario: Instructions are limited to 1000 characters
    When I type 1001 characters in the instructions field
    Then the instructions field should contain 1000 characters
    And I should see the character counter "1000/1000"

  # ---------- Attachments ----------

  @smoke
  Scenario: Attachments section suggests what to upload
    Then the attachments section should mention prescription, appointment receipt and reports
    And it should say attachments are optional

  @happy-path
  Scenario Outline: Upload a supported attachment
    When I add an attachment "<file>" of type "<type>" and size "<size>"
    Then I should see an upload progress indicator for "<file>"
    And when the upload finishes "<file>" should appear in the attachments list with a remove option

    Examples:
      | file                    | type | size  |
      | prescription.jpg        | JPG  | 2 MB  |
      | appointment_receipt.png | PNG  | 6 MB  |
      | old_reports.pdf         | PDF  | 10 MB |

  @happy-path
  Scenario Outline: Attach via camera or file picker
    When I tap "Add attachment"
    Then I should see the options "Take photo" and "Choose file"
    When I choose "<source>"
    And I provide a valid JPG file
    Then the file should appear in the attachments list

    Examples:
      | source      |
      | Take photo  |
      | Choose file |

  @negative
  Scenario Outline: Reject unsupported or oversize attachments
    When I add an attachment "<file>" of type "<type>" and size "<size>"
    Then I should see the error "<error>"
    And "<file>" should not appear in the attachments list

    Examples:
      | file          | type | size    | error                                  |
      | huge_scan.pdf | PDF  | 10.1 MB | File is too large. Max 10 MB per file  |
      | report.docx   | DOCX | 1 MB    | Only JPG, PNG or PDF files are allowed |
      | clip.mp4      | MP4  | 4 MB    | Only JPG, PNG or PDF files are allowed |
      | scan.heic     | HEIC | 2 MB    | Only JPG, PNG or PDF files are allowed |

  @negative
  Scenario: Maximum of 5 attachments
    Given I have added 5 attachments
    Then the "Add attachment" button should be disabled
    And I should see the hint "Up to 5 files"

  @negative
  Scenario: Selecting more files than remaining slots
    Given I have added 3 attachments
    When I select 4 files at once in the file picker
    Then only 2 files should be added
    And I should see the message "You can attach up to 5 files"

  @error
  Scenario: Upload failure can be retried
    Given the upload API fails for the next request
    When I add an attachment "prescription.jpg" of type "JPG" and size "2 MB"
    Then "prescription.jpg" should show "Upload failed" with a "Retry" option
    When the upload API recovers
    And I tap "Retry" on "prescription.jpg"
    Then "prescription.jpg" should appear as uploaded

  @ui-state
  Scenario: Next is disabled while an upload is in progress
    Given I have filled all required fields
    When I start uploading "old_reports.pdf"
    Then the "Next" button should be disabled until the upload completes

  @ui-state
  Scenario: Removing an attachment
    Given I have uploaded "prescription.jpg"
    When I tap remove on "prescription.jpg"
    Then "prescription.jpg" should not appear in the attachments list
    And the "Add attachment" button should be enabled

  @negative
  Scenario: A failed upload does not block Next once removed
    Given I have filled all required fields
    And "appointment_receipt.png" has failed to upload
    When I tap remove on "appointment_receipt.png"
    Then the "Next" button should be enabled

  # ---------- Navigation ----------

  @navigation
  Scenario: Back to B2 keeps B3 inputs in the draft
    Given I have selected the hospital "AIIMS, Ansari Nagar"
    And I have selected the pickup time "09:30 AM"
    And I have entered instructions "Use the east gate"
    When I tap the back button
    And I tap "Next" on the "B2" screen
    Then the hospital should still be "AIIMS, Ansari Nagar"
    And the pickup time should still be "09:30 AM"
    And the instructions should still be "Use the east gate"

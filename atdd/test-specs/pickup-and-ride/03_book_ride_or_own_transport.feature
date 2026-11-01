# Screens: P6 Book ride or skip, P7a Book ride, P7b Own transport (Caretaker app)
# Source: proxy-care-ui-ux-state-for-api-design.md (PRD v2.3) §5 P6/P7a/P7b, §1 Ride, §2 ride events + visit stage, §8 common UI states; PRD 3.2
# Assumption: the stage becomes OWN_TRANSPORT_TO_HOSPITAL on choosing skip on P6, because §2 resumes that stage at P7b.
# Assumption: the stage becomes RIDE_TO_HOSPITAL when the ride is booked, because §2 resumes that stage at P8a.
# The return leg (D1, D2a, D2b) belongs to the drop-off phase and is not covered here.

@caretaker-app @pickup-and-ride @P6 @P7a @P7b
Feature: Caretaker books a ride to the hospital or uses own transport
  As a Caretaker who has picked up the patient
  I want to book a partner ride or record that we are using other transport
  So that the patient reaches the hospital in whatever way suits them

  Rules (context §1, §2, §5):
    - A ride is optional. The caretaker may skip it for a family car, ambulance, walking or other transport.
    - Ride options are Cab XL, Cab and Auto, each with provider, ETA, fare estimate and suitability tag.
    - The family pays for rides through a payment request. Own transport has no fare and no payment request.

  Background:
    Given today is "2026-11-02"
    And I am logged in to the Caretaker app as "Anita Verma" with KYC "APPROVED"
    And I am assigned to booking "PC-2481" for patient "Kamla Mehta" with mobility "WHEELCHAIR"
    And booking "PC-2481" is in state "IN_PROGRESS" with stage "PICKED_UP"
    And the hospital for booking "PC-2481" is "Max Super Speciality Hospital, Saket"
    And the sponsoring user is "Rohan Mehta", relation "Son"

  # ---------- P6 Book ride or skip ----------

  @smoke
  Scenario: P6 offers booking a ride or skipping it
    When I open the "P6 Book ride or skip" screen
    Then I should see the option to book a ride
    And I should see the option to skip the ride

  @smoke @navigation
  Scenario: Choosing to book a ride opens P7a
    Given I am on the "P6 Book ride or skip" screen
    When I choose to book a ride
    Then I should be on the "P7a Book ride" screen
    And no ride should exist yet for leg "TO_HOSPITAL"

  @smoke @navigation
  Scenario: Choosing to skip the ride opens P7b
    Given I am on the "P6 Book ride or skip" screen
    When I choose to skip the ride
    Then I should be on the "P7b Own transport" screen
    And the visit stage of booking "PC-2481" should be "OWN_TRANSPORT_TO_HOSPITAL"
    And no ride should exist for leg "TO_HOSPITAL"

  # ---------- P7a Book ride: display ----------

  @smoke
  Scenario: P7a shows the route, the options and who pays
    When I open the "P7a Book ride" screen
    Then I should see the route from the patient's home to "Max Super Speciality Hospital, Saket"
    And I should see the ride options "Cab XL", "Cab" and "Auto"
    And I should see a note that the family pays through a payment request
    And I should not see any option to pay for the ride myself

  Scenario Outline: Each ride option shows its details
    Given the ride partners return the following option:
      | option   | provider   | eta   | fare_estimate | suitability   |
      | <option> | <provider> | <eta> | <fare>        | <suitability> |
    When I open the "P7a Book ride" screen
    Then the option "<option>" should show the provider "<provider>"
    And the option "<option>" should show the ETA "<eta>"
    And the option "<option>" should show the fare estimate "<fare>"
    And the option "<option>" should show the suitability tag "<suitability>"

    Examples:
      | option | provider | eta   | fare | suitability         |
      | Cab XL | Uber     | 6 min | ₹420 | Best for wheelchair |
      | Cab    | Uber     | 4 min | ₹320 | Fits a folded chair |
      | Auto   | Rapido   | 3 min | ₹180 | Short trips         |

  # ---------- P7a Book ride: booking ----------

  @negative
  Scenario: Book is disabled until an option is selected
    Given no ride option is selected
    When I open the "P7a Book ride" screen
    Then the "Book" button should be disabled

  @smoke @happy-path
  Scenario Outline: Booking a ride opens the ride status
    Given I am on the "P7a Book ride" screen
    When I select the ride option "<option>"
    And I tap "Book"
    Then a ride should be created for booking "PC-2481" with leg "TO_HOSPITAL", vehicle "<option>" and provider "<provider>"
    And the visit stage of booking "PC-2481" should be "RIDE_TO_HOSPITAL"
    And I should be on the "P8a Ride status" screen
    And no payment request should exist yet for the ride

    Examples:
      | option | provider |
      | Cab XL | Uber     |
      | Cab    | Uber     |
      | Auto   | Rapido   |

  Scenario: Selecting another option replaces the selection
    Given I am on the "P7a Book ride" screen
    And I have selected the ride option "Cab"
    When I select the ride option "Cab XL"
    Then only the ride option "Cab XL" should be selected

  @negative
  Scenario: A double tap on Book creates one ride
    Given I am on the "P7a Book ride" screen
    And I have selected the ride option "Cab"
    When I double tap "Book"
    Then exactly one ride should be created for leg "TO_HOSPITAL"
    And I should be on the "P8a Ride status" screen

  @ui-state
  Scenario: Book shows progress while the ride partner responds
    Given the ride booking request is slow
    And I am on the "P7a Book ride" screen
    And I have selected the ride option "Cab"
    When I tap "Book"
    Then the "Book" button should show a loader and be disabled

  @negative
  Scenario: Ride booking failure keeps the caretaker on P7a
    Given the ride booking request will fail
    And I am on the "P7a Book ride" screen
    And I have selected the ride option "Cab"
    When I tap "Book"
    Then I should see an error
    And I should remain on the "P7a Book ride" screen
    And the ride option "Cab" should still be selected
    And no ride should exist for leg "TO_HOSPITAL"
    And the visit stage of booking "PC-2481" should be "PICKED_UP"

  # ---------- P7a Book ride: states ----------

  @ui-state
  Scenario: Skeleton while ride options load
    Given the ride options request is slow
    When I open the "P7a Book ride" screen
    Then I should see skeleton placeholders for the ride options
    And the "Book" button should be disabled

  @ui-state @negative
  Scenario: Error state with retry when ride options fail to load
    Given the ride options request fails
    When I open the "P7a Book ride" screen
    Then I should see an error with a "Retry" button
    When the ride options request succeeds
    And I tap "Retry"
    Then I should see the ride options "Cab XL", "Cab" and "Auto"

  @ui-state @negative
  Scenario: Offline banner blocks booking
    Given I am on the "P7a Book ride" screen
    And I have selected the ride option "Cab"
    When the device goes offline
    Then I should see an offline banner
    And the "Book" button should be disabled

  @pending-design
  Scenario: No ride partner has a vehicle available
    Given the ride partners return no options
    When I open the "P7a Book ride" screen
    Then the empty state and the route to "P7b Own transport" should be confirmed by design

  @pending-design
  Scenario: An option does not suit the patient's mobility
    Given the patient's mobility is "BEDRIDDEN"
    When I open the "P7a Book ride" screen
    Then it should be confirmed by design whether "Auto" is blocked or only tagged as unsuitable

  @pending-design
  Scenario: The fare estimate has changed when Book is tapped
    Given the fare estimate for "Cab" changed after the options loaded
    When I select the ride option "Cab"
    And I tap "Book"
    Then the expected behaviour should be confirmed by design

  # ---------- P7b Own transport ----------

  @smoke
  Scenario: P7b shows the transport modes without any fare
    When I open the "P7b Own transport" screen
    Then I should see the modes "Family car", "Ambulance", "Walking" and "Other"
    And I should not see any fare
    And I should see the actions "I've reached the hospital" and "Book a ride instead"

  @smoke @happy-path
  Scenario Outline: Reaching the hospital with own transport
    Given I am on the "P7b Own transport" screen
    When I select the mode "<mode>"
    And I tap "I've reached the hospital"
    Then I should be on the "H1 Services to-do" screen
    And the visit stage of booking "PC-2481" should be "AT_HOSPITAL"
    And no ride should exist for leg "TO_HOSPITAL"
    And no "RIDE_TO_HOSPITAL" payment request should exist for booking "PC-2481"

    Examples:
      | mode       |
      | Family car |
      | Ambulance  |
      | Walking    |
      | Other      |

  @navigation
  Scenario: Book a ride instead switches to P7a
    Given I am on the "P7b Own transport" screen
    When I tap "Book a ride instead"
    Then I should be on the "P7a Book ride" screen
    When I select the ride option "Cab"
    And I tap "Book"
    Then the visit stage of booking "PC-2481" should be "RIDE_TO_HOSPITAL"
    And I should be on the "P8a Ride status" screen

  @negative
  Scenario: Reaching the hospital failure keeps the caretaker on P7b
    Given the reached hospital request will fail
    And I am on the "P7b Own transport" screen
    And I have selected the mode "Family car"
    When I tap "I've reached the hospital"
    Then I should see an error
    And I should remain on the "P7b Own transport" screen
    And the visit stage of booking "PC-2481" should be "OWN_TRANSPORT_TO_HOSPITAL"

  @negative
  Scenario: A double tap records one hospital arrival
    Given I am on the "P7b Own transport" screen
    And I have selected the mode "Family car"
    When I double tap "I've reached the hospital"
    Then exactly one arrival should be recorded for booking "PC-2481"

  @pending-design
  Scenario: Reaching the hospital without selecting a mode
    Given no transport mode is selected
    When I open the "P7b Own transport" screen
    Then it should be confirmed by design whether a mode is required or preselected

  @pending-design
  Scenario: Other transport needs a description
    Given I am on the "P7b Own transport" screen
    When I select the mode "Other"
    Then it should be confirmed by design whether a description is needed

  # ---------- Navigation and resume ----------

  @navigation
  Scenario: Back from P7a returns to P6
    Given I am on the "P7a Book ride" screen
    When I press the device back button
    Then I should be on the "P6 Book ride or skip" screen
    And no ride should exist for leg "TO_HOSPITAL"

  @navigation
  Scenario Outline: The resume arrow opens the right screen for the transport stage
    Given booking "PC-2481" has stage "<stage>"
    And I am on the "P1 Home" screen
    Then the ongoing visit card should show the stage badge "<badge>"
    When I tap the resume arrow on the ongoing visit card
    Then I should be on the "<screen>" screen

    Examples:
      | stage                     | badge                  | screen               |
      | PICKED_UP                 | Patient picked up      | P6 Book ride or skip |
      | OWN_TRANSPORT_TO_HOSPITAL | In transit to hospital | P7b Own transport    |
      | RIDE_TO_HOSPITAL          | Ride to hospital       | P8a Ride status      |

  @ui-state
  Scenario: Reopening the app from P7a before booking resumes at P6
    Given I am on the "P7a Book ride" screen
    And no ride exists for leg "TO_HOSPITAL"
    When I force close and reopen the Caretaker app
    And I tap the resume arrow on the ongoing visit card
    Then I should be on the "P6 Book ride or skip" screen

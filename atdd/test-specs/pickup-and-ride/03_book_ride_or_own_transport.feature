# Screens: P6 Book ride or skip, P7a Book ride, P7b Own transport (Caretaker app)
# Source: proxy-care-ui-ux-state-for-api-design.md (PRD v2.3) §5 P6/P7a/P7b, §1 Ride, §2 ride events + visit stage, §8 common UI states; PRD 3.2
# Assumption: the stage becomes OWN_TRANSPORT_TO_HOSPITAL on choosing skip on P6, because §2 resumes that stage at P7b.
# Assumption: the stage becomes RIDE_TO_HOSPITAL when the ride is booked, because §2 resumes that stage at P8a.
# Assumption: Book is disabled until an option is selected (§8 "disabled CTAs until valid"); the design does not mention a preselected option.
# Ride option sample data is illustrative. Suitability tag wording is not in the design.
# The return leg (D1, D2a, D2b) belongs to the drop-off phase and is not covered here.
#
# Open design questions (no scenario until decided):
#   - Is an unsuitable option blocked or only tagged, for example Auto for a BEDRIDDEN patient?
#   - What happens if the fare estimate has changed when Book is tapped?
#   - Is a transport mode required or preselected on P7b? Does "Other" need a description?

@regression @caretaker-app @pickup-and-ride @P6 @P7a @P7b
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
    And I am logged in to the Caretaker app as "Anita Verma"
    And I am assigned to booking "PC-2481" for patient "Kamla Mehta" with mobility "WHEELCHAIR"
    And the booking is in state "IN_PROGRESS" with stage "PICKED_UP"
    And the hospital is "Max Super Speciality Hospital, Saket"
    And the ride partners offer:
      | option | provider | eta   | fare_estimate | suitability         |
      | Cab XL | Uber     | 6 min | ₹420          | Best for wheelchair |
      | Cab    | Uber     | 4 min | ₹320          | Fits a folded chair |
      | Auto   | Rapido   | 3 min | ₹180          | Short trips         |

  # ---------- P6 Book ride or skip ----------

  @smoke @navigation
  Scenario: Choosing to book a ride opens P7a without creating a ride
    Given I am on the "P6 Book ride or skip" screen
    When I choose to book a ride
    Then I should be on the "P7a Book ride" screen
    And the booking should have 0 rides for leg "TO_HOSPITAL"

  @smoke @navigation
  Scenario: Choosing to skip the ride opens P7b
    Given I am on the "P6 Book ride or skip" screen
    When I choose to skip the ride
    Then I should be on the "P7b Own transport" screen
    And the booking should have stage "OWN_TRANSPORT_TO_HOSPITAL"
    And the booking should have 0 rides for leg "TO_HOSPITAL"

  @negative
  Scenario: A failed skip keeps the caretaker on P6
    Given the "record own transport" request will fail
    And I am on the "P6 Book ride or skip" screen
    When I choose to skip the ride
    Then I should see the "error" state
    And I should be on the "P6 Book ride or skip" screen
    And the booking should have stage "PICKED_UP"

  # ---------- P7a Book ride: display ----------

  @smoke @happy-path
  Scenario: P7a shows the route, the options and who pays
    When I open the "P7a Book ride" screen
    Then I should see the route to "Max Super Speciality Hospital, Saket"
    And I should see the ride options "Cab XL, Cab, Auto"
    And I should see the note that the family pays through a payment request
    And I should not see any option to pay the fare myself

  @happy-path
  Scenario Outline: Each ride option shows its details
    When I open the "P7a Book ride" screen
    Then the ride option "<option>" should show "<provider>", "<eta>", "<fare>" and "<suitability>"

    Examples:
      | option | provider | eta   | fare | suitability         |
      | Cab XL | Uber     | 6 min | ₹420 | Best for wheelchair |
      | Cab    | Uber     | 4 min | ₹320 | Fits a folded chair |
      | Auto   | Rapido   | 3 min | ₹180 | Short trips         |

  @ui-state
  Scenario: Only the options the partners return are shown
    Given the ride partners offer only "Cab"
    When I open the "P7a Book ride" screen
    Then I should see the ride options "Cab"

  # ---------- P7a Book ride: booking ----------

  @ui-validation
  Scenario: Book is disabled until an option is selected
    When I open the "P7a Book ride" screen
    Then no ride option should be selected
    And the "Book" button should be disabled

  @ui-validation
  Scenario: Selecting an option enables Book
    Given I am on the "P7a Book ride" screen
    When I select the ride option "Cab"
    Then the "Book" button should be enabled

  @ui-validation
  Scenario: Selecting another option replaces the selection
    Given I am on the "P7a Book ride" screen
    And I have selected the ride option "Cab"
    When I select the ride option "Cab XL"
    Then the only selected ride option should be "Cab XL"

  @smoke @happy-path
  Scenario Outline: Booking a ride opens the ride status
    Given I am on the "P7a Book ride" screen
    When I book the ride option "<option>"
    Then the booking should have 1 ride for leg "TO_HOSPITAL" with vehicle "<option>" and provider "<provider>"
    And the booking should have stage "RIDE_TO_HOSPITAL"
    And I should be on the "P8a Ride status" screen
    Examples:
      | option | provider |
      | Cab XL | Uber     |
      | Cab    | Uber     |
      | Auto   | Rapido   |

  @negative
  Scenario: A double tap on Book creates one ride
    Given I am on the "P7a Book ride" screen
    And I have selected the ride option "Cab"
    When I double tap "Book"
    Then the booking should have 1 ride for leg "TO_HOSPITAL"
    And I should be on the "P8a Ride status" screen

  @ui-state
  Scenario: Book shows progress while the ride partner responds
    Given the "book ride" request is slow
    And I am on the "P7a Book ride" screen
    When I book the ride option "Cab"
    Then the "Book" button should be loading

  @negative
  Scenario: A failed booking keeps the caretaker on P7a
    Given the "book ride" request will fail
    And I am on the "P7a Book ride" screen
    When I book the ride option "Cab"
    Then I should see the "error" state
    And I should be on the "P7a Book ride" screen
    And the only selected ride option should be "Cab"
    And the booking should have 0 rides for leg "TO_HOSPITAL"
    And the booking should have stage "PICKED_UP"

  # ---------- P7a Book ride: states ----------

  @ui-state
  Scenario: Skeleton while ride options load
    Given the "ride options" request is slow
    When I open the "P7a Book ride" screen
    Then I should see the "loading skeleton" state
    And the "Book" button should be disabled

  @ui-state @negative
  Scenario: A failed load shows an error with Retry
    Given the "ride options" request will fail
    When I open the "P7a Book ride" screen
    Then I should see the "error" state
    And the "Retry" button should be enabled
    And the "Book" button should be disabled

  @ui-state
  Scenario: Retry reloads the ride options
    Given the "ride options" request failed on the "P7a Book ride" screen
    And the "ride options" request has recovered
    When I tap "Retry"
    Then I should see the ride options "Cab XL, Cab, Auto"

  @ui-state @negative
  Scenario: Going offline blocks booking
    Given I am on the "P7a Book ride" screen
    And I have selected the ride option "Cab"
    When the device goes offline
    Then I should see the "offline banner" state
    And the "Book" button should be disabled

  @ui-state @pending-design
  Scenario: No ride can be booked when no partner has a vehicle
    Given the ride partners offer nothing
    When I open the "P7a Book ride" screen
    Then I should see the "no rides" state
    And the "Book" button should be disabled

  # ---------- P7b Own transport ----------

  @smoke @happy-path
  Scenario: P7b shows the transport modes without any fare
    When I open the "P7b Own transport" screen
    Then I should see the transport modes "Family car, Ambulance, Walking, Other"
    And I should not see any fare
    And the "Book a ride instead" button should be enabled

  @smoke @happy-path
  Scenario Outline: Reaching the hospital with own transport
    Given I am on the "P7b Own transport" screen
    When I reach the hospital by "<mode>"
    Then I should be on the "H1 Services to-do" screen
    And the booking should have stage "AT_HOSPITAL"
    And the booking should have 0 rides for leg "TO_HOSPITAL"

    Examples:
      | mode       |
      | Family car |
      | Ambulance  |
      | Walking    |
      | Other      |

  @navigation
  Scenario: Book a ride instead opens P7a
    Given I am on the "P7b Own transport" screen
    When I tap "Book a ride instead"
    Then I should be on the "P7a Book ride" screen

  @happy-path
  Scenario: A ride booked after choosing own transport replaces the transit stage
    Given the booking has stage "OWN_TRANSPORT_TO_HOSPITAL"
    And I opened the "P7a Book ride" screen from the "P7b Own transport" screen
    When I book the ride option "Cab"
    Then the booking should have stage "RIDE_TO_HOSPITAL"
    And I should be on the "P8a Ride status" screen

  @negative
  Scenario: A failed arrival keeps the caretaker on P7b
    Given the "reach hospital" request will fail
    And the booking has stage "OWN_TRANSPORT_TO_HOSPITAL"
    And I am on the "P7b Own transport" screen
    When I reach the hospital by "Family car"
    Then I should see the "error" state
    And I should be on the "P7b Own transport" screen
    And the booking should have stage "OWN_TRANSPORT_TO_HOSPITAL"

  @negative
  Scenario: A double tap records one hospital arrival
    Given I am on the "P7b Own transport" screen
    And I have selected the transport mode "Family car"
    When I double tap "I've reached the hospital"
    Then the booking should have 1 "Reached hospital" timeline event

  @ui-state @negative
  Scenario: Going offline blocks recording the arrival
    Given I am on the "P7b Own transport" screen
    When the device goes offline
    Then I should see the "offline banner" state
    And the "I've reached the hospital" button should be disabled

  # ---------- Navigation and resume ----------

  @navigation @device
  Scenario: Back from P7a returns to P6 without booking
    Given I opened the "P7a Book ride" screen from the "P6 Book ride or skip" screen
    When I press the device back button
    Then I should be on the "P6 Book ride or skip" screen
    And the booking should have 0 rides for leg "TO_HOSPITAL"

  @navigation @device
  Scenario: Back from P7a returns to P7b when opened from there
    Given the booking has stage "OWN_TRANSPORT_TO_HOSPITAL"
    And I opened the "P7a Book ride" screen from the "P7b Own transport" screen
    When I press the device back button
    Then I should be on the "P7b Own transport" screen
    And the booking should have stage "OWN_TRANSPORT_TO_HOSPITAL"

  @navigation
  Scenario Outline: The resume arrow follows the transport stage
    Given the booking has stage "<stage>"
    And I am on the "P1 Home" screen
    When I resume the ongoing visit
    Then I should be on the "<screen>" screen

    Examples:
      | stage                     | screen               |
      | PICKED_UP                 | P6 Book ride or skip |
      | OWN_TRANSPORT_TO_HOSPITAL | P7b Own transport    |
      | RIDE_TO_HOSPITAL          | P8a Ride status      |

  @navigation @device
  Scenario Outline: Reopening the app before a ride is booked resumes from the stage
    Given the booking has stage "<stage>"
    And I am on the "P7a Book ride" screen
    When I force close and reopen the app
    And I resume the ongoing visit
    Then I should be on the "<screen>" screen

    Examples:
      | stage                     | screen               |
      | PICKED_UP                 | P6 Book ride or skip |
      | OWN_TRANSPORT_TO_HOSPITAL | P7b Own transport    |

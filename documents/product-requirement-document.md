# Product Requirements Document (PRD)

**Project Name:** Proxy Care (Working Title)

**Document Version:** 2.3

**Status:** Baseline Draft

---

## 1. Domain Entities & Core Relationships

### 1.1 Core Domain Entities (Locked Nomenclature)

* **User:** The primary account holder, manager, and sponsor responsible for booking, funding, and monitoring care for a relative.
* **Patient:** The family member receiving care, medical assistance, and transit support during appointments.
* **Caretaker:** The vetted companion/helper assigned to accompany the Patient during medical visits and transit.
* **Ride Partner:** The third-party transit driver (e.g., Uber/Rapido integration) assigned to transport the Patient and Caretaker.

### 1.2 Key Relations

* **Patient-User Association:** The linked structural relationship between a `User` account owner and a `Patient` entity, permitting the User to manage and sponsor care on behalf of the Patient.

---

## 2. Onboarding Workflows

### 2.1 Caretaker Onboarding

#### KYC Flow

* Sign up with mobile number & verify via OTP
* **Basic Information Capture:**
* Full Name *(Mandatory)*
* Sex *(Mandatory)*
* Age
* Mobile Number *(Mandatory)*
* Emergency Contact Number *(Mandatory)*
* Residential Address *(Mandatory)*
* Email Address *(Mandatory)*
* Aadhaar Verification (Consent Required) *(Mandatory)*
* PAN Verification (Consent Required) *(Mandatory)*
* Occupation
* Marital Status (Single / Married)
* Photo (Upper Body Portrait)


* **Identity Verification:** Video KYC / Field Agent Visit

#### Account & Payout Setup

* Bank Account Details (Account Number, IFSC Code, Bank Name, Branch, PIN Code)
* ₹1 test deposit to confirm the caretaker’s bank account.

---

### 2.2 Two-Stage User & Family Onboarding

#### Stage A: User Onboarding

* Sign up with mobile number & verify via OTP
* **Profile Setup:** Name, Sex, Age, Mobile Number, Address

#### Stage B: Family Onboarding

* **Link Family Members:** Connect all family member profiles (`Patients`) to the account.
* **Capture Patient Information:** Submit details and define the relationship/kinship for each linked family member.

---

## 3. Core Operational Workflows

### 3.1 Service Booking Workflow

1. **Selection:** `User` selects a family member (`Patient`) and taps **"Book Caretaker"**.
2. **Visit Details Input:**
* **Date of Visit**
* **Visit Purpose:** OPD / Consultation, Diagnostics, Day Care Procedures, Admission / Discharge, or Emergency. *(Display illustrative iconography and an info tooltip `(i)` next to selection pills).*  User can select multiple visit purpose. For ex:- select OPD and Diagnostic.
* **Facility Information:** Hospital name, address / map location, department, doctor name.
* **Pickup time:** caretaker will arrive at this pickup time.
* **Special Instructions:** Instructions for the `Caretaker`. Like carry old reports, reach hospital at 2PM, etc
* **Attachment:**  Like prescription, pre-booked appointment receipt, reach hospital at 2PM, etc.


3. **Price Calculation & Confirmation:**
* System displays the standardized booking charge.
* `User` reviews cancellation policy and clicks **"Confirm & Pay"**.
* `User` will be redirected to 3rd party screen to pay the booking charges


4. **Dispatch Lifecycle:**
* Booking created with state: `WAITING`.
* Broadcasted to nearby `Caretakers`.
* First `Caretaker` to accept updates booking state to: `ASSIGNED`.



---

### 3.2 Ride & Transit Management (Pickup Phase)

1. `Caretaker` arrives at `Patient` location and confirms arrival via OTP verification.
2. `Caretaker` initiates transit booking to the hospital via integrated third-party service (Uber/Rapido).
3. **Ride Telemetry Updates:** Real-time event updates (`Ride Partner Assigned`, `Ride Partner Arrived`, `Trip Started`, `Trip Completed`).
4. **Transit Payment:** User will get a payment request`.
5. When user clicks "Approve & Pay", will be redirected to 3rd party screen to pay the transit charges.

---

### 3.3 Live Location Tracking

* Activated when `Caretaker` toggles **"Reaching Pickup Location"**.
* **Visibility Matrix:**
* **Caretaker:** Views self live location and `Patient` home address location (does not view Patient live location).
* **User:** Views real-time live location of the `Caretaker`.
* **Patient:** Cannot view any location telemetry.



---

### 3.4 Hospital Appointment Processing

* **Pre-Booked Flow:** Proceed to assigned department/desk and wait.
* **Walk-In / Desk Booking Flow:**
1. `Caretaker` books the appointment at the hospital appointment desk.
2. `Caretaker` scans the invoice QR code.
3. System verifies the QR code against MCC code and hospital name.
4. **Hospital Payment:** User will get a payment request`.
5. When user clicks "Approve & Pay", will be redirected to 3rd party screen to pay the  hospital charges

Note:- 1. The flow of hospital is generic like procedure started and procedure completed only. There will be no other steps in between this.
For example:- 
1. Caretaker will see the todo list page in which he will see all the selected services. 
2. For each service a badge will be shown - Procedure pending/procedure started/procedure completed.
3. For each service there will be two buttons - start and complete.
4. After procedure starts this button will convert to disabled state and vice versa for procedure completed button.
5. Once the procedure complete whole card will be in disabled state.



7. **Tele-Consultation / Communication Option:** `User` may initiate a phone/video call with `Caretaker` to join during consultation if permitted by facility. When user clicks on "Phone/Video call Caretaker" button then he will be redirected to WhatsApp.
8. **Completion Notification:** `User` notified automatically upon completion of consultation/procedure.

---

### 3.5 Ride & Transit Management (Drop-off Phase)

1. `Caretaker` initiates return ride to home via app.
2. System updates transit status events from integration layer (`Ride Partner Assigned`, `Ride Partner Arrived`, `Trip Started`, `Trip Completed`).
4. **Transit Payment:** User will get a payment request`.
5. When user clicks "Approve & Pay", will be redirected to 3rd party screen to pay the transit charges.
---

### 3.6 Final Settlement

1. System audits all pending or ongoing transactions for the booking.
2. **If all transactions are cleared:**
3. System calculates final `Caretaker` payout bill using `CaretakerFeesPaymentStrategy`.
4. User will get a Caretaker payment request fee.
5. When user clicks "Pay Caretaker", will be redirected to 3rd party screen to pay the transit charges.
6. After successful payment, amount will credited to ProxyCare account.
7. And that amount will be reflected in the caretaker virtual wallet.
Note: Here caretaker's virtual wallet is just a normal chip which shows his total pending earnings that is yet to be withdrawn. 

### 3.7 Caretaker payment processing and dispute.
* Upon successful payment, system generates the `Caretaker` bill and triggers payment processing.
* If unsettled, `Caretaker` may log a formal dispute via the app.



---

## 4. Financial & Pricing Architecture

### 4.1 Fee Calculation Strategy (Company & Caretaker Payout)

Standard Booking Baseline = **Base Condition Charges + 3-Hour Caretaker Block**

| Patient Mobility Category | Caretaker Hourly Wage | Platform Margin & Risk (Constant) | Nominal Platform Fee | Total Consumer Price (3-Hr Block) |
| --- | --- | --- | --- | --- |
| **1. Normal / Ambulatory** | **₹200 / hr** | ₹400 | ₹99 | **₹1,099** |
| **2. Wheelchair-Bound** | **₹250 / hr** | ₹400 | ₹99 | **₹1,249** |
| **3. Bedridden / Dependent** | **₹320 / hr** | ₹400 | ₹99 | **₹1,459** |

* **Platform Nominal Fee (₹99):** Covers non-refundable payment gateway transaction fees, SMS/notification API costs, and dispatch overhead.
* **Platform Risk & Margin (₹400):** Covers liability insurance, support overhead, platform operational maintenance, and margin.

---

## 5. Cancellation & Protection Policy

* **Standard Cancellation (>8 Hours Prior):** Full refund to User's bank account minus nominal platform fee (₹99).
* **Late Cancellation (<8 Hours Prior):** Full refund minus 3-hour caretaker fee (₹600 base) and nominal platform fee (₹99).
* **On-Site No-Show / Ultra-Late Cancellation:** Deducts full standard booking charge.
* **Pro-Rated Adjustments:** If caretaker service duration is under 3 hours for quick diagnostic visits (e.g., X-Ray, Ultrasound), refund rules apply as dictated by the duration-based refund strategy.
# AntreIn — Product Brief

> **Document:** `docs/00-product-brief.md`  
> **Status:** Draft v1.1  
> **Product Type:** Mobile-first booking, payment, check-in, and real-time queue platform  
> **Initial Vertical:** Barbershops  
> **Primary Market:** Indonesia  
> **Primary Client:** Flutter mobile application  
> **Repository Strategy:** Monorepo  
> **Document Language:** English  
> **Last Updated:** 2026-07-21

---

## 1. Executive Summary

**AntreIn** is a mobile-first platform that allows customers to discover service businesses, book an available service, choose a staff member, pay online or at the venue, check in, and monitor their queue position in real time.

The initial release focuses exclusively on **barbershops** so the product remains focused, testable, and realistic for a solo full-stack portfolio project. The platform may later expand to salons, small clinics, workshops, spas, consultation studios, and other appointment-based local services.

AntreIn addresses several common problems:

- Customers cannot see the expected queue before arriving.
- Customers spend too much time waiting at the venue.
- Businesses manage bookings through chat messages, notebooks, or spreadsheets.
- Staff schedules and booking slots can overlap.
- Businesses lose revenue because of no-shows.
- Customers repeatedly ask when they will be served.
- Booking, payment, cancellation, and queue histories are difficult to audit.

The project is intentionally designed to demonstrate end-to-end engineering capabilities across:

- Flutter mobile development.
- Backend API development.
- Authentication and authorization.
- Relational database design.
- Booking and scheduling.
- Payment gateway integration.
- Verified webhook processing.
- Real-time communication.
- Push notifications.
- File uploads.
- Database transactions and concurrency control.
- Docker-based deployment.
- Automated testing and observability.

---

## 2. Product Vision

> Make booking and waiting for local services more predictable, transparent, and convenient for both customers and service businesses.

AntreIn aims to reduce unnecessary physical waiting by giving customers a reliable way to reserve a service and track queue progress from their mobile device.

---

## 3. Product Mission

AntreIn helps service businesses:

- Accept structured bookings.
- Prevent schedule conflicts.
- Manage walk-ins and scheduled customers in one queue.
- Reduce no-shows through optional deposits.
- Give customers transparent waiting information.
- Keep booking, payment, and service histories.
- Deliver a more professional customer experience.

---

## 4. Product Principles

### 4.1 Mobile First

The main customer and staff workflows must be fast and comfortable on mobile devices.

### 4.2 Backend as the Source of Truth

The backend is authoritative for:

- Prices.
- Deposit requirements.
- Slot availability.
- Staff eligibility.
- Booking status.
- Payment status.
- Queue number.
- Queue order.
- Cancellation and refund eligibility.

### 4.3 Real Time Only Where It Adds Value

Real-time communication is used for queue and service-status changes. Standard data retrieval continues to use REST APIs.

### 4.4 Simple Before Flexible

The MVP supports one focused business vertical before introducing generic marketplace behavior.

### 4.5 Invalid States Must Be Prevented

The product must prevent states such as:

- Two active bookings assigned to the same staff member during overlapping times.
- Duplicate queue numbers for the same outlet and business date.
- A booking confirmed before a required payment is verified.
- A completed booking that never entered service.
- Check-in for a cancelled or expired booking.
- A refund greater than the amount paid.

### 4.6 Graceful Failure

Network or provider failures must not cause users to lose context. The application must explain the current state and provide safe recovery actions.

### 4.7 Auditability

Critical actions must be traceable, including:

- Booking status changes.
- Payment status changes.
- Queue changes.
- Manual queue reordering.
- Refunds.
- Staff permission changes.
- Manual cancellations.
- Price changes.

---

## 5. Problem Statement

### 5.1 Customer Problems

Customers commonly experience:

- Unclear waiting times.
- No visibility into queue length.
- Difficulty confirming staff availability.
- Booking through unstructured chat conversations.
- No reliable booking or payment proof.
- No reminder before an appointment.
- No clear explanation when a booking changes or is cancelled.
- Repeated travel to a business that is already full.

### 5.2 Business Problems

Barbershop owners and staff commonly experience:

- Manual booking records.
- Overlapping appointments.
- Customers arriving late or not arriving.
- Difficulty deciding who should be served next.
- No reliable operational history.
- No clear separation between paid and unpaid bookings.
- Repeated customer questions about queue position.
- Limited visibility into daily completion, cancellation, and no-show performance.

---

## 6. Target Users

### 6.1 Customer

A user who wants to:

- Discover a barbershop.
- View available services and staff.
- Select a schedule.
- Create a booking.
- Make a payment.
- Check in.
- Monitor a live queue.
- Review a completed service.

### 6.2 Business Owner

A user responsible for:

- Business profile.
- Services and prices.
- Staff management.
- Operating hours.
- Booking policies.
- Payment policies.
- Queue operations.
- Operational summaries.

### 6.3 Staff

A business member such as:

- Barber.
- Cashier.
- Front-desk staff.
- Manager.

Staff may manage bookings, check-ins, queues, and service completion according to assigned permissions.

### 6.4 Platform Administrator

A platform operator responsible for:

- Business verification.
- Account moderation.
- Report handling.
- Administrative corrections.
- Platform-level auditing.

A complete admin interface is not required in the first mobile MVP.

---

## 7. Initial Product Scope

The first release serves **barbershops in Indonesia**.

Initial business characteristics:

- One or more barbers.
- Several services with different prices and durations.
- Scheduled bookings.
- Walk-in customers.
- Queue management per outlet.
- Full payment, deposit, or pay-at-location options.
- One outlet per business during the MVP.

### 7.1 Future Expansion

Possible future verticals:

- Salons.
- Small clinics.
- Vehicle workshops.
- Spas.
- Consultation studios.
- Local public services.
- Multi-category service marketplaces.

These expansions are outside the MVP.

---

## 8. Product Goals

### 8.1 Customer Goals

Customers must be able to:

- Create a booking in a few clear steps.
- See service prices before confirming.
- Choose a preferred staff member or any available staff member.
- Pay through an available method.
- Receive reminders.
- Check in.
- See queue position and estimated waiting time.
- Know when they are being called.
- View booking and payment history.

### 8.2 Business Goals

Businesses must be able to:

- Configure services, staff, and operating hours.
- Prevent schedule conflicts.
- Combine booked and walk-in customers in one queue.
- Reduce no-shows through deposits.
- Manage service progress.
- Identify payment status.
- Review a basic daily operational summary.

### 8.3 Portfolio Goals

The project must demonstrate:

- Mobile frontend engineering.
- Backend architecture.
- Authentication and session management.
- Role-based and ownership-based authorization.
- Database transactions.
- Concurrency-safe booking.
- Payment and webhook handling.
- Real-time updates.
- Push notifications.
- Deployment and CI.
- Automated testing.
- Technical documentation.

---

## 9. Non-Goals

The MVP does not include:

- Multi-country support.
- Multi-currency support.
- Complex franchise management.
- Payroll.
- Inventory management.
- Full point-of-sale functionality.
- Accounting.
- Business subscription billing.
- Loyalty points.
- Referral programs.
- Complex promotion engines.
- Customer-to-staff chat.
- Video calls.
- Dynamic pricing.
- AI recommendations.
- Route tracking.
- A complete web administration platform.
- Staff revenue sharing.
- Marketplace commission and merchant settlement.
- Multiple product languages.
- Cross-timezone booking.

---

## 10. User Roles and Permissions

### 10.1 Customer Permissions

A customer can:

- Register and sign in.
- Manage their profile.
- Browse businesses.
- View business details, services, staff, policies, and schedules.
- Create a booking.
- Select an available payment option.
- Complete an online payment.
- View payment status.
- Cancel a booking when allowed.
- Check in.
- View their queue status.
- View booking history.
- Submit a review after service completion.
- Manage notification preferences.

A customer cannot:

- Change service prices.
- Set a payment as paid.
- Generate or modify queue numbers.
- Mark a booking as completed.
- Access another customer’s private data.

### 10.2 Business Owner Permissions

A business owner can:

- Manage the business profile.
- Manage the initial outlet.
- Manage services and prices.
- Manage staff and permissions.
- Configure operating hours and closed dates.
- Configure booking, cancellation, and payment policies.
- View all bookings belonging to the business.
- Operate the queue.
- View basic operational reporting.

### 10.3 Staff Permissions

Staff can perform allowed actions such as:

- View bookings for assigned outlets.
- View the active queue.
- Check in customers.
- Call, recall, or skip queue entries.
- Start and complete services.
- Mark no-shows.
- Confirm pay-at-location payments.
- Add limited internal operational notes.

Staff cannot modify business-wide configuration unless explicitly authorized.

### 10.4 Platform Administrator Permissions

A platform administrator can:

- Access platform-level business records.
- Verify or reject businesses.
- Suspend accounts.
- Review audit records.
- Handle reports and administrative corrections.

---

## 11. Core Customer Journeys

### 11.1 Registration and Login

```text
Open the application
→ Register
→ Verify identity when required
→ Sign in
→ Complete profile
→ Enter the customer home screen
```

**Expected result:** the customer has an active authenticated account and can create bookings.

### 11.2 Discover a Business

```text
Home
→ Browse or search businesses
→ Open business details
→ Review services, prices, staff, hours, ratings, and policies
```

Business details must show at least:

- Business name.
- Address.
- Operating hours.
- Available services.
- Prices.
- Estimated service durations.
- Available staff.
- Supported payment options.
- Cancellation policy.
- Rating summary.

### 11.3 Create a Booking

```text
Select a business
→ Select a service
→ Select a staff member or “Any available staff”
→ Select a date
→ Select an available time slot
→ Review booking details
→ Select a payment option
→ Confirm the booking
```

Expected booking status:

- `pending_payment`, when payment is required before confirmation.
- `confirmed`, for pay-at-location or an already verified payment.

### 11.4 Complete an Online Payment

```text
Booking created
→ Backend creates payment
→ Customer opens payment instructions
→ Customer completes payment
→ Payment provider sends webhook
→ Backend verifies webhook
→ Payment becomes paid
→ Booking becomes confirmed
→ Customer receives an update
```

The mobile application cannot mark a payment as paid.

### 11.5 Check In

```text
Customer arrives
→ Opens the active booking
→ Customer or authorized staff initiates check-in
→ Backend validates booking and check-in window
→ Booking becomes checked_in
→ Customer receives a queue entry
```

QR check-in may be added later.

### 11.6 Monitor the Live Queue

```text
Customer checks in
→ Backend assigns a queue number
→ Customer sees people ahead and estimated waiting time
→ Staff calls the next entry
→ Real-time state updates affected clients
→ Customer receives a push notification
→ Service begins
```

Minimum queue information:

- Queue number.
- Number of people ahead.
- Current queue number being served.
- Estimated waiting time.
- Current booking and queue status.

### 11.7 Complete the Service

```text
Staff starts the service
→ Booking becomes in_service
→ Staff completes the service
→ Booking becomes completed
→ Remaining pay-at-location balance is resolved
→ Customer may submit a review
```

### 11.8 Cancel a Booking

```text
Customer opens booking details
→ Requests cancellation
→ Backend evaluates policy
→ Booking is cancelled
→ Queue entry is removed when applicable
→ Refund is initiated when eligible
→ Customer receives an update
```

### 11.9 Walk-In Customer

```text
Customer arrives without a booking
→ Staff creates a walk-in booking
→ Service is selected
→ Staff is selected or assigned
→ Backend assigns a queue number
→ Customer enters the active queue
```

Walk-in support allows a business to use AntreIn without forcing every customer to install the application.

---

## 12. Business User Journeys

### 12.1 Business Setup

```text
Business owner receives access
→ Creates business profile
→ Configures outlet
→ Adds services
→ Adds staff
→ Configures schedules and policies
→ Activates business
```

### 12.2 Daily Queue Operation

```text
Staff opens queue dashboard
→ Reviews booked and walk-in customers
→ Checks in arrivals
→ Calls the next customer
→ Starts service
→ Completes service
→ Handles skipped or no-show entries
```

### 12.3 Pay-at-Location Confirmation

```text
Staff opens booking
→ Reviews outstanding amount
→ Receives payment
→ Confirms payment
→ Backend records payment and audit event
```

### 12.4 Daily Summary

```text
Owner opens dashboard
→ Reviews bookings, completed services, cancellations, no-shows, and payments
```

---

## 13. Feature Scope

### 13.1 Authentication

#### MVP

- Email and password registration.
- Login.
- Logout.
- Access-token refresh.
- Forgot password.
- Password reset.
- Role-aware session.
- Device registration for notifications.

#### Later

- Google Sign-In.
- Apple Sign-In.
- Phone-number authentication.
- Multi-factor authentication.

### 13.2 Customer Profile

#### MVP

- Name.
- Email.
- Phone number.
- Profile image.
- Notification preferences.
- Booking history.

#### Later

- Favorite businesses.
- Saved payment preferences.
- Loyalty profile.
- Multiple dependent profiles.

### 13.3 Business Discovery

#### MVP

- Business list.
- Search by business name.
- Business details.
- Service catalog.
- Staff list.
- Operating hours.
- Basic rating summary.
- Business images.

#### Later

- Map discovery.
- Distance sorting.
- Advanced filters.
- Personalized recommendations.
- Featured businesses.

### 13.4 Business Management

#### MVP

- Business profile.
- One outlet.
- Service management.
- Staff management.
- Operating hours.
- Closed dates.
- Booking policy.
- Payment policy.
- Basic daily summary.

#### Later

- Multiple outlets.
- Advanced permissions.
- Shift planning.
- Franchise hierarchy.
- Advanced analytics.

### 13.5 Service Management

Each service includes:

- Name.
- Description.
- Price.
- Deposit amount or percentage.
- Duration.
- Active state.
- Eligible staff.
- Optional image.

A service used by historical bookings must not be physically deleted when doing so would damage history.

### 13.6 Staff Management

Each staff profile includes:

- Name.
- Profile image.
- Role.
- Active state.
- Eligible services.
- Working schedule.

Business owners can:

- Add staff.
- Update staff.
- Deactivate staff.
- Assign services.
- Configure availability.

### 13.7 Scheduling

Available slots are calculated from:

- Business operating hours.
- Staff working hours.
- Service duration.
- Existing active bookings.
- Break periods.
- Closed dates.
- Minimum booking lead time.
- Maximum booking horizon.

Rules:

- Flutter never calculates the authoritative slot result.
- The backend recalculates availability during booking creation.
- A slot may appear available but become unavailable before confirmation.
- The API returns a stable conflict error.
- The MVP uses the outlet timezone, initially `Asia/Jakarta`.

### 13.8 Booking

A booking contains:

- Customer.
- Business.
- Outlet.
- Service.
- Staff.
- Scheduled start time.
- Expected duration.
- Price snapshot.
- Payment option.
- Booking status.
- Customer notes.
- Creation timestamp.

Booking types:

- Scheduled booking.
- Walk-in booking.

Staff selection:

- Specific staff member.
- Any available staff member.

### 13.9 Payment

Supported payment options:

1. Pay at location.
2. Full online payment.
3. Deposit payment.

Businesses may enable one or more options.

Deposit forms:

- Fixed amount.
- Percentage of service price.

Example:

```text
Service price: IDR 50,000
Required deposit: IDR 10,000
Remaining balance: IDR 40,000
```

The backend is authoritative for payment amount and payment status.

A payment may become paid through:

- A verified payment-gateway webhook.
- An authorized staff confirmation for pay-at-location.
- A verified administrative reconciliation process.

Payment expiration behavior:

- Payment becomes `expired`.
- Pending booking is cancelled or expired according to policy.
- Slot becomes available again.
- Customer receives an update.

Refund support:

- Full refund.
- Partial refund.
- Deposit refund.
- Refund status tracking.

The actual methods depend on the selected provider and may include:

- Virtual accounts.
- QRIS.
- E-wallets.
- Bank transfer.
- Retail payment channels.

### 13.10 Real-Time Queue

Queue scope:

- Per outlet.
- Per business date.

Queue sources:

- Checked-in scheduled bookings.
- Walk-in bookings.

Customer queue information:

- Queue number.
- Number of people ahead.
- Current number being served.
- Estimated waiting time.
- Queue status.

Staff actions:

- Check in.
- Call.
- Recall.
- Skip.
- Start service.
- Complete service.
- Mark no-show.
- Cancel an entry.

Default ordering:

1. Checked-in scheduled bookings according to applicable schedule policy.
2. Walk-ins according to check-in time.
3. Manual adjustment by authorized staff when necessary.

Manual changes must be audited.

Queue number rules:

- Unique per outlet and business date.
- Generated by the backend.
- Protected by a database constraint.
- Safe under concurrent requests.

Estimated waiting time may initially use:

```text
People ahead × average active service duration
```

The estimate is informative and not a guaranteed appointment time.

### 13.11 Notifications

Customer notification events:

- Booking created.
- Payment successful.
- Payment nearing expiration.
- Payment expired.
- Booking confirmed.
- Booking cancelled.
- Appointment reminder.
- Check-in successful.
- Queue nearly reached.
- Customer called.
- Service completed.
- Refund updated.

Staff notification events:

- New booking.
- Payment successful.
- Customer checked in.
- Customer cancelled.
- Payment failed or expired.

MVP channels:

- Push notification.
- In-app notification history.

Future channels:

- Email.
- WhatsApp.
- SMS.

### 13.12 Reviews and Ratings

A customer may review a booking when:

- Booking status is `completed`.
- The customer owns the booking.
- No review exists for the booking.

Review fields:

- Rating from 1 to 5.
- Optional comment.

The business cannot edit customer reviews.

### 13.13 File Uploads

MVP files:

- Customer profile image.
- Business logo.
- Business gallery images.
- Staff profile image.
- Service image.

Rules:

- Validate MIME type.
- Limit size.
- Validate ownership.
- Avoid exposing private files publicly.
- Prevent failed uploads from corrupting the owning record.

### 13.14 Basic Reporting

Customer views:

- Upcoming booking.
- Active booking.
- Booking history.
- Payment history.

Business views:

- Bookings today.
- Completed services.
- Cancelled bookings.
- No-show count.
- Gross paid amount.
- Pending payments.
- Active queue count.

Advanced analytics are outside the MVP.

---

## 14. Business Rules

### 14.1 General Rules

- The backend is the source of truth.
- Every critical status transition is validated.
- Primary identifiers must be difficult to guess.
- Historical records remain stable after configuration changes.
- Booking service name, duration, and price are stored as snapshots.
- Users access only resources allowed by role, membership, outlet assignment, and ownership.

### 14.2 Booking Rules

- A customer must be authenticated.
- The business, outlet, service, and staff must be active.
- The staff member must be eligible for the selected service.
- The slot must be available when the backend processes the booking.
- Bookings cannot be created in the past.
- Booking lead-time and horizon rules must be satisfied.
- One staff member cannot have overlapping active bookings.
- Businesses may limit the number of active bookings per customer.
- Payment-required bookings remain `pending_payment` until verified.
- Pay-at-location bookings may become `confirmed` immediately.
- Duplicate requests with the same idempotency key must not create duplicate bookings.

### 14.3 Cancellation Rules

Cancellation policy must be configurable.

Example policy:

- More than 6 hours before the appointment: full eligible refund.
- Between 2 and 6 hours: partial refund.
- Less than 2 hours: deposit is non-refundable.
- No-show: deposit is non-refundable.

These values are examples, not final defaults.

### 14.4 Rescheduling Rules

Rescheduling is not included in the first MVP.

A future implementation must:

- Validate the new slot.
- Release the previous slot.
- Recalculate payment differences.
- Preserve status history.
- Execute changes transactionally.

### 14.5 Check-In Rules

- Booking must be `confirmed`.
- Check-in must occur within a configurable window.
- Cancelled or expired bookings cannot check in.
- Check-in is idempotent.
- A booking cannot receive more than one active queue entry.

### 14.6 Queue Rules

- Queue numbers are generated by the backend.
- Queue numbers are unique per outlet and business date.
- One booking has at most one active queue entry.
- Customers can view only safe public queue information.
- Staff can manage only assigned outlet queues.
- Skip is not cancellation.
- No-show is recorded explicitly.
- Queue transitions are validated.

### 14.7 Payment Rules

- Payment amount is calculated by the backend.
- Flutter does not submit an authoritative price.
- Provider references and provider event IDs are unique.
- Webhook signatures are verified.
- Webhook handling is idempotent.
- Duplicate webhooks do not duplicate business effects.
- A paid payment cannot return to pending.
- Refund amount cannot exceed paid amount.
- Pay-at-location confirmation requires authorized staff.
- Manual payment corrections require an audit record.

### 14.8 Review Rules

- Only completed bookings can be reviewed.
- One booking can receive one review.
- Review ownership is validated.
- Platform administrators may moderate abusive content.

---

## 15. Status Definitions

### 15.1 Booking Status

```text
draft
pending_payment
confirmed
checked_in
waiting
called
in_service
completed
cancelled
expired
no_show
```

| Status | Description |
|---|---|
| `draft` | Booking has not been submitted |
| `pending_payment` | Booking is waiting for required payment |
| `confirmed` | Booking is valid and has a reserved slot |
| `checked_in` | Customer arrival has been validated |
| `waiting` | Customer is in the active queue |
| `called` | Customer is currently being called |
| `in_service` | Service is in progress |
| `completed` | Service has finished |
| `cancelled` | Booking has been cancelled |
| `expired` | Booking or payment exceeded its allowed time |
| `no_show` | Customer did not arrive according to policy |

### 15.2 Payment Status

```text
pending
paid
failed
expired
cancelled
refund_pending
partially_refunded
refunded
```

| Status | Description |
|---|---|
| `pending` | Waiting for payment |
| `paid` | Payment has been verified |
| `failed` | Payment attempt failed |
| `expired` | Payment exceeded its expiration time |
| `cancelled` | Payment was cancelled |
| `refund_pending` | Refund is being processed |
| `partially_refunded` | Part of the payment was refunded |
| `refunded` | All eligible funds were refunded |

### 15.3 Queue Status

```text
waiting
called
skipped
in_service
completed
cancelled
no_show
```

### 15.4 Business Status

```text
pending_verification
active
suspended
rejected
inactive
```

### 15.5 Staff Status

```text
invited
active
inactive
suspended
```

---

## 16. Status Transition Rules

### 16.1 Booking Transitions

```text
draft → pending_payment
draft → confirmed
pending_payment → confirmed
pending_payment → expired
pending_payment → cancelled
confirmed → checked_in
confirmed → cancelled
confirmed → no_show
checked_in → waiting
waiting → called
called → in_service
called → skipped
called → no_show
skipped → waiting
in_service → completed
```

Terminal states:

```text
completed
cancelled
expired
no_show
```

A correction from a terminal state requires an authorized, audited administrative action.

### 16.2 Payment Transitions

```text
pending → paid
pending → failed
pending → expired
pending → cancelled
paid → refund_pending
refund_pending → partially_refunded
refund_pending → refunded
partially_refunded → refund_pending
partially_refunded → refunded
```

---

## 17. Product Screens

### 17.1 Shared Screens

- Splash.
- Onboarding.
- Login.
- Registration.
- Forgot password.
- Profile.
- Notifications.
- Settings.
- Role selection or switching.

### 17.2 Customer Screens

- Customer home.
- Business list.
- Search.
- Business details.
- Service selection.
- Staff selection.
- Date and time selection.
- Booking review.
- Payment-option selection.
- Payment instructions.
- Payment status.
- Booking success.
- Upcoming bookings.
- Active booking.
- Live queue.
- Booking history.
- Booking details.
- Cancellation flow.
- Review form.

### 17.3 Owner and Staff Screens

The MVP may use the same Flutter application with role-aware navigation.

- Business setup.
- Business dashboard.
- Service management.
- Staff management.
- Operating hours.
- Closed dates.
- Booking list.
- Booking details.
- Queue dashboard.
- Walk-in creation.
- Pay-at-location confirmation.
- Daily summary.
- Business settings.

### 17.4 Platform Administration

A complete admin mobile interface is outside the MVP.

Administrative actions may initially use:

- Minimal internal tooling.
- Protected administrative endpoints.
- Safe scripts.
- A future web dashboard.

---

## 18. Navigation Principles

- Navigation is role-aware.
- Users never see actions they cannot perform.
- Deep links validate authentication and resource access.
- Notification taps open the related resource when authorized.
- Expired sessions return to login without corrupting safe local state.
- Payment navigation preserves the booking context.
- Role switching refreshes role-scoped state and real-time subscriptions.

---

## 19. Error and Empty States

The application must explicitly handle:

- No internet.
- Backend unavailable.
- Session expired.
- Unauthorized.
- Forbidden.
- Slot no longer available.
- Payment failed.
- Payment expired.
- Booking cancelled.
- Queue unavailable.
- Business closed.
- Empty business list.
- Empty booking history.
- Empty notifications.
- Upload failure.
- Unknown failure.

Error messages must:

- Be understandable.
- Avoid exposing internal implementation details.
- Provide the next available action.
- Offer retry only when safe.

---

## 20. Offline and Network Behavior

AntreIn is not a full offline application.

Cacheable data:

- User profile.
- Recent business list.
- Recent business details.
- Upcoming booking summary.
- Booking-history pages.
- Notification history.
- Static configuration.

Online verification required:

- Slot availability.
- Booking creation.
- Payment status.
- Check-in.
- Queue position.
- Queue commands.
- Cancellation eligibility.
- Refund status.

The MVP does not automatically queue critical offline mutations.

---

## 21. Security Requirements

- Passwords use a modern secure hash.
- Access tokens are short-lived.
- Refresh sessions are revocable.
- Mobile tokens are stored in platform secure storage.
- Authorization is enforced on the backend.
- Sensitive values are redacted from logs.
- Payment webhooks are verified.
- Sensitive endpoints are rate-limited.
- File uploads are validated.
- Inputs are validated server-side.
- Secrets are excluded from the repository.
- Production uses HTTPS.
- Critical actions are audited.
- Production errors do not expose stack traces.
- Administrative functions follow least privilege.

---

## 22. Privacy Requirements

- Collect only necessary personal information.
- Customers cannot access another customer’s private data.
- Staff see only data required for operations.
- Account deletion must be supported before a real public launch.
- Retention periods must be defined before production.
- Payment credentials are not stored directly by AntreIn.
- Notification delivery requires appropriate consent.
- Public queue views must not expose customer names or contact details.

---

## 23. Performance Expectations

Initial expectations:

- Main screens become usable under normal mobile-network conditions.
- Lists use pagination.
- Images use optimized sizes or thumbnails.
- Booking creation returns a clear result.
- Queue updates normally arrive within a few seconds.
- Push notifications are complementary, not authoritative.
- WebSocket reconnection does not duplicate events.
- Critical mutations support safe idempotency where required.

Precise service-level targets are defined later in technical documents.

---

## 24. Reliability Expectations

- Duplicate requests do not create duplicate bookings.
- Duplicate payment webhooks do not create duplicate payment effects.
- Duplicate queue commands do not create invalid transitions.
- Durable state is committed before real-time events are published.
- Notification failure does not fail a booking or payment.
- Payment success can be recovered when the mobile application is closed.
- A backend restart does not lose persisted state.
- WebSocket reconnect is followed by authoritative state recovery.

---

## 25. Accessibility and Usability

- Text must have sufficient contrast.
- Primary actions must be easy to reach.
- Status must not rely only on color.
- Forms must use labels and clear validation messages.
- Loading states must explain what is happening.
- Queue numbers must be large and readable.
- Currency must use consistent Indonesian Rupiah formatting.
- Dates and times must use familiar Indonesian formats.
- Product language must remain simple and non-technical.

---

## 26. Localization

MVP localization:

- Product language: Bahasa Indonesia.
- Documentation language: English.
- Currency: Indonesian Rupiah.
- Locale: `id-ID`.
- Initial timezone: `Asia/Jakarta`.

Application strings should use localization resources rather than hardcoded text.

---

## 27. Analytics Events

### Authentication

```text
registration_started
registration_completed
login_succeeded
login_failed
```

### Discovery

```text
business_viewed
service_selected
staff_selected
slot_selected
```

### Booking

```text
booking_started
booking_created
booking_failed
booking_cancelled
booking_completed
```

### Payment

```text
payment_started
payment_succeeded
payment_failed
payment_expired
refund_requested
refund_completed
```

### Queue

```text
customer_checked_in
queue_joined
queue_called
service_started
service_completed
customer_no_show
```

Analytics must avoid unnecessary sensitive data.

---

## 28. Success Metrics

### 28.1 Product Metrics

- Booking completion rate.
- Payment success rate.
- Cancellation rate.
- No-show rate.
- Average waiting time.
- Check-in rate.
- Service completion rate.
- Average review rating.
- Active businesses.
- Bookings per business.

### 28.2 Engineering Metrics

- Passing CI pipelines.
- Critical-module automated tests.
- No duplicate bookings in concurrency tests.
- No duplicate queue numbers in concurrency tests.
- Idempotent webhook tests.
- Recoverable WebSocket reconnect.
- Reproducible Docker environment.
- Generated and validated API contract.
- Health checks and structured logs.

---

## 29. MVP Definition

### 29.1 Customer End-to-End Flow

```text
Register
→ Login
→ Browse a barbershop
→ Select service
→ Select staff
→ Select schedule
→ Create booking
→ Select payment option
→ Complete sandbox payment or pay at location
→ Receive confirmation
→ Check in
→ View live queue
→ Get called
→ Receive service
→ Submit review
```

### 29.2 Business End-to-End Flow

```text
Receive business access
→ Configure business
→ Create services
→ Add staff
→ Configure operating hours
→ Receive booking
→ Confirm pay-at-location payment when required
→ Check in customer
→ Manage queue
→ Start service
→ Complete service
→ View daily summary
```

### 29.3 Engineering Completion

The MVP is complete when:

- Flutter supports customer and business roles.
- Backend API is available.
- PostgreSQL stores durable state.
- Authentication and authorization work.
- Booking conflicts are prevented.
- Sandbox payment is integrated.
- Webhooks are verified.
- Real-time queue updates work.
- Push notifications work.
- Docker-based local setup exists.
- CI pipelines exist.
- Critical unit and integration tests exist.
- OpenAPI documentation exists.
- Seed data and demo accounts exist.

---

## 30. MVP Priorities

### Must Have

- Authentication.
- Customer and business roles.
- Business profile.
- Service management.
- Staff management.
- Operating hours.
- Slot availability.
- Booking creation.
- Pay at location.
- Sandbox online payment.
- Booking status.
- Check-in.
- Live queue.
- Push notifications.
- Booking history.
- Reviews.
- Basic reporting.
- Audit trail for critical actions.

### Should Have

- Deposit payment.
- Cancellation policy.
- Sandbox refund.
- Walk-ins.
- Business gallery.
- Notification history.
- Basic analytics events.

### Could Have

- Any available staff.
- Favorite businesses.
- QR check-in.
- Business replies to reviews.
- Advanced filters.
- Minimal admin interface.

### Will Not Have in MVP

- Loyalty points.
- Subscription billing.
- Multiple outlets.
- Chat.
- Inventory.
- Payroll.
- Full POS.
- AI recommendations.
- Multiple currencies.
- Multiple product languages.
- Complex promotions.

---

## 31. Delivery Milestones

### M0 — Product Foundation

- Product brief.
- Roles.
- Core journeys.
- Business rules.
- MVP scope.
- Status lifecycle.

### M1 — System Foundation

- System architecture.
- Monorepo structure.
- Environment strategy.
- Local development setup.
- API conventions.
- Error conventions.

### M2 — Authentication

- Registration.
- Login.
- Token refresh.
- Logout.
- Profile.
- Role-aware navigation.

### M3 — Business Setup

- Business profile.
- Services.
- Staff.
- Operating hours.
- Closed dates.

### M4 — Discovery and Scheduling

- Business list.
- Business details.
- Staff availability.
- Slot generation.
- Slot validation.

### M5 — Booking

- Create booking.
- Booking details.
- Upcoming bookings.
- Booking history.
- Cancellation.

### M6 — Payment

- Pay at location.
- Sandbox payment.
- Verified webhook.
- Payment expiration.
- Deposits.
- Refund flow.

### M7 — Check-In and Queue

- Check-in.
- Walk-in.
- Queue-number generation.
- Queue dashboard.
- Real-time updates.
- Queue notifications.

### M8 — Completion and Review

- Start service.
- Complete service.
- Reviews.
- Basic daily summary.

### M9 — Production Readiness

- CI.
- Automated testing.
- Docker deployment.
- Logging.
- Monitoring.
- Security review.
- Seed and demo data.
- Final documentation.

---

## 32. Risks and Mitigations

### 32.1 Excessive Scope

**Risk:** The project becomes too large to finish.

**Mitigation:**

- Focus on barbershops.
- Support one outlet.
- Use one Flutter application.
- Use one payment provider sandbox.
- Keep reports basic.
- Deliver through vertical slices.

### 32.2 Booking Race Condition

**Risk:** Two customers obtain the same staff slot.

**Mitigation:**

- Backend validation.
- Database constraints.
- Transactions.
- Conflict mapping.
- Concurrency tests.

### 32.3 Duplicate Queue Number

**Risk:** Concurrent requests create the same queue number.

**Mitigation:**

- Atomic counter update.
- Database transaction.
- Unique constraint.
- Concurrency test.

### 32.4 Duplicate Payment Webhook

**Risk:** One provider event is applied more than once.

**Mitigation:**

- Unique provider event ID.
- Idempotent handler.
- Transaction.
- Raw-event storage.
- Audit trail.

### 32.5 Real-Time Disconnection

**Risk:** A customer misses queue updates.

**Mitigation:**

- WebSocket reconnect.
- REST state refresh after reconnect.
- Push notification as a complementary channel.
- Staff recall action.

### 32.6 Notification Failure

**Risk:** A customer does not receive a call notification.

**Mitigation:**

- Notification is not the source of truth.
- Live queue remains visible.
- Delivery retry.
- Staff can recall.
- Timestamps remain visible.

### 32.7 Payment Integration Complexity

**Risk:** Payment delays the entire MVP.

**Mitigation:**

- Implement pay at location first.
- Use sandbox only.
- Integrate one provider.
- Delay marketplace settlement.
- Keep payment methods limited.

### 32.8 Multi-Role UX Complexity

**Risk:** One application becomes confusing.

**Mitigation:**

- Role-aware navigation.
- Separate role-specific home screens.
- Hide unavailable actions.
- Show role switching only for multi-role users.

---

## 33. Assumptions

- The MVP operates in Indonesia.
- Users have a smartphone and internet connection.
- Each business has at least one staff member.
- A business may use a shared device for staff operations.
- Payment and push notifications use third-party providers.
- The outlet timezone is fixed.
- Prices use Indonesian Rupiah.
- The admin interface can remain minimal.
- The project is initially a portfolio and demonstration product.
- Production legal and compliance requirements require additional review before commercial launch.

---

## 34. Open Product Decisions

The following decisions must be resolved before dependent implementation begins:

- Final product name and brand identity.
- Payment gateway provider.
- Push-notification provider.
- Customer self-check-in versus staff-only check-in.
- Fixed versus percentage deposit.
- Default cancellation policy.
- Whether walk-in is included in the first demo.
- Whether customer and business roles share one account.
- Whether business registration requires admin approval.
- Waiting-time estimation method.
- Whether staff can manually reorder queues.
- Automatic versus manual booking confirmation.
- Whether payment fees are passed to the customer.
- Data-retention periods.
- Demo hosting environment.

Open decisions must not block unrelated modules.

---

## 35. Product Acceptance Criteria

The product brief is considered validated when:

- All primary roles are defined.
- Customer and business journeys are defined end to end.
- Booking, payment, and queue lifecycles are clear.
- MVP and non-MVP scope are separated.
- Critical business rules are documented.
- Backend and Flutter teams can use this document as a shared source of truth.
- No implementation contradicts the product principles.
- Scope changes are recorded through document updates.

---

## 36. Documentation Ownership

This document is the source of truth for AntreIn product requirements.

```text
docs/
├── 00-product-brief.md
├── 01-system-architecture.md
├── 02-api-contract.md
├── backend/
│   ├── backend-brief.md
│   ├── database-design.md
│   ├── authentication.md
│   ├── booking-payment.md
│   └── realtime-queue.md
└── frontend/
    ├── flutter-brief.md
    ├── app-architecture.md
    ├── navigation-flow.md
    ├── state-management.md
    └── ui-feature-spec.md
```

Conflict resolution:

1. Product brief defines **what** the product must do.
2. System architecture defines **how the system is structured**.
3. API contract defines communication between backend and Flutter.
4. Backend brief defines server implementation.
5. Flutter brief defines mobile implementation.

Business-rule changes must update the appropriate product or domain document before implementation is changed.

---

## 37. Glossary

| Term | Definition |
|---|---|
| Booking | Reservation for a service at a selected time |
| Walk-in | Customer without a scheduled booking |
| Check-in | Confirmation that the customer has arrived |
| Queue | Ordered list of customers waiting for service |
| Queue Number | Backend-generated daily outlet sequence |
| Deposit | Partial payment required before service |
| Pay at Location | Payment completed at the business venue |
| Payment Gateway | Third-party provider that processes online payment |
| Webhook | Server-to-server event sent by an external provider |
| No-show | Customer who does not arrive according to policy |
| Slot | A bookable time period |
| Staff | Business member who provides or manages services |
| Business Owner | Primary business administrator |
| Platform Administrator | Operator of the AntreIn platform |
| Source of Truth | Authoritative system for a category of state |
| Idempotency | Repeated processing produces the same business result |
| Audit Log | Append-only record of sensitive changes |
| Real-Time Event | Event delivered to active clients immediately after state changes |

---

## 38. Final Product Statement

AntreIn is a booking, payment, check-in, and real-time queue platform for barbershops in Indonesia.

The MVP must prove that a customer can safely complete:

```text
Discover
→ Book
→ Pay
→ Check in
→ Wait remotely
→ Get called
→ Receive service
→ Review
```

The MVP must also prove that a business can:

```text
Configure services
→ Receive bookings
→ Validate payments
→ Check in customers
→ Operate the queue
→ Complete services
→ Review daily activity
```

Success is not measured only by feature count. It is measured by consistent business rules, safe state transitions, reliable Flutter–backend integration, and correct behavior under concurrent requests and network failures.

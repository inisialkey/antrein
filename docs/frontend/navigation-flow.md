# AntreIn — Navigation Flow

> **Document:** `docs/frontend/navigation-flow.md`  
> **Status:** Draft v1.0  
> **Router:** GoRouter  
> **Document Language:** English  
> **Last Updated:** 2026-07-21

---

## 1. Purpose

This document defines AntreIn mobile navigation, route ownership, authentication redirects, role switching, deep links, and feature flows.

---

## 2. Navigation Principles

- Navigation is declarative.
- Authentication state controls protected routes.
- Role context controls role-specific shells.
- Resource access is still validated by the backend.
- Deep links are recoverable after login.
- Payment return does not imply success.
- Route names are stable.
- Navigation does not carry authoritative domain state.

---

## 3. Root Navigation States

```text
initializing
unauthenticated
authenticated_without_role
customer_mode
business_mode
fatal_initialization_error
```

---

## 4. Root Redirect Logic

```text
App initializing
→ Splash

No session
→ Auth flow

Authenticated, profile loading
→ Session loading

Authenticated, one role
→ Role home

Authenticated, multiple roles and no valid last role
→ Role selection

Deep link pending
→ Resolve after session and role
```

---

## 5. Route Tree

```text
/
├── splash
├── onboarding
├── auth
│   ├── login
│   ├── register
│   ├── forgot-password
│   └── reset-password
├── role-selection
├── customer
│   ├── home
│   ├── businesses
│   │   └── :businessId
│   ├── booking-flow
│   ├── bookings
│   │   └── :bookingId
│   ├── payments
│   │   └── :paymentId
│   ├── queue
│   │   └── :bookingId
│   ├── notifications
│   └── profile
└── business
    ├── dashboard
    ├── bookings
    │   └── :bookingId
    ├── queue
    ├── walk-in
    ├── services
    ├── staff
    ├── schedule
    ├── reports
    ├── settings
    └── profile
```

---

## 6. Route Naming

Examples:

```text
splash
login
register
customerHome
businessDetail
bookingService
bookingStaff
bookingSchedule
bookingReview
bookingPayment
customerBookingDetail
customerQueue
businessDashboard
businessQueue
businessServiceList
```

Use named navigation rather than raw path strings in feature code.

---

## 7. Customer Shell

Bottom navigation:

```text
Home
Bookings
Notifications
Profile
```

Each branch preserves its navigation stack when appropriate.

---

## 8. Business Shell

Bottom navigation:

```text
Dashboard
Bookings
Queue
Business
Profile
```

Visibility depends on permissions.

A staff member without `business.manage` does not see management configuration.

---

## 9. Authentication Flow

```text
Splash
→ Restore session

No session
→ Login

Login success
→ Fetch /me
→ Resolve roles
→ Enter selected role
```

Registration success may directly create a session.

---

## 10. Pending Deep Link

When a protected deep link opens without a valid session:

```text
Store pending link
→ Navigate to login
→ Login succeeds
→ Validate role
→ Fetch resource
→ Open destination
```

Invalid or unauthorized resource:

```text
Show safe not-found/forbidden state
→ Do not expose existence details
```

---

## 11. Customer Discovery Flow

```text
Customer Home
→ Business List/Search
→ Business Detail
→ Service Selection
```

Back behavior returns through the same discovery stack.

---

## 12. Booking Flow

```text
Business Detail
→ Select Service
→ Select Staff
→ Select Date and Slot
→ Booking Review
→ Select Payment Option
→ Submit Booking
```

Result branches:

### Pay at Location

```text
Booking Success
→ Booking Detail
```

### Online Payment

```text
Payment Pending
→ External Checkout
→ Return to App
→ Refresh Status
→ Confirmed or Pending/Failed
```

---

## 13. Booking Draft State

Booking selections should live in a flow coordinator/Cubit, not route parameters.

The route may carry only:

```text
businessId
```

Selected service, staff, slot, notes, and payment option remain in flow state.

Leaving the flow prompts for confirmation if meaningful selections exist.

---

## 14. Payment Return Flow

Deep-link example:

```text
antrein://payments/return?paymentId=pay_...
```

Handling:

```text
Open payment status screen
→ Fetch backend payment
→ Subscribe to updates
→ Show confirmed state only after backend says paid
```

---

## 15. Customer Booking Detail

Available actions depend on server response:

```text
pay
refresh payment
cancel
check in
view queue
review
```

Flutter does not independently calculate action eligibility.

---

## 16. Customer Queue Flow

```text
Booking Detail
→ Check In
→ Queue Screen
→ Called State
→ In Service State
→ Completed State
```

Queue screen is deep-linkable.

On resume, it refetches current state.

---

## 17. Business Setup Flow

First-time owner:

```text
Business Setup Intro
→ Business Profile
→ Outlet Details
→ Services
→ Staff
→ Operating Hours
→ Review
→ Submit
→ Pending Verification or Dashboard
```

Progress may be resumable.

---

## 18. Business Booking Flow

```text
Business Booking List
→ Booking Detail
→ Available Staff Action
```

Actions may include:

- Check in.
- Mark no-show.
- Confirm payment.
- Cancel with reason.

---

## 19. Business Queue Flow

```text
Queue Dashboard
→ Select Entry
→ Call
→ Recall / Skip
→ Start Service
→ Complete Service
```

Commands remain on the queue screen or focused bottom sheets to minimize navigation overhead.

---

## 20. Walk-In Flow

```text
Queue Dashboard
→ Add Walk-In
→ Customer Details
→ Select Service
→ Select Staff
→ Review
→ Create
→ Queue Dashboard highlights new entry
```

---

## 21. Role Switching

Entry point:

```text
Profile or app-bar role switcher
```

Flow:

```text
Select role
→ Confirm if active form exists
→ Clear old role-scoped state
→ Leave old WebSocket rooms
→ Resolve permissions
→ Enter new role home
```

---

## 22. Logout Flow

```text
Profile
→ Logout confirmation
→ Call backend logout
→ Clear local session
→ Reset router
→ Login
```

Logout completes locally even when backend call fails.

---

## 23. Notification Navigation

Push or in-app notification resource types:

```text
booking
payment
queue
review
business
```

Handler:

```text
Resolve resource
→ Ensure session
→ Ensure role
→ Fetch current state
→ Navigate
```

---

## 24. Error Navigation

Do not navigate for every error.

Inline errors are preferred for:

- Validation.
- Slot conflict.
- Payment pending.
- Queue conflict.

Dedicated pages:

- Session expired.
- Maintenance.
- Resource unavailable.
- Initialization failure.

---

## 25. Route Guards

Guards/redirects:

- Authentication.
- Role availability.
- Business membership.
- Setup completion.
- Feature flag.
- Pending deep link.

Backend remains authoritative for actual resource access.

---

## 26. Back Navigation

Rules:

- Payment checkout return never returns to stale review submission.
- Completed booking flow resets booking draft.
- Role shell back behavior exits nested stack before app.
- Forms confirm discard when dirty.
- Queue command sheets close after confirmed result.

---

## 27. Navigation Testing

Required:

- Unauthenticated redirect.
- Session restoration.
- Multi-role selection.
- Pending deep link after login.
- Unauthorized business route.
- Payment return.
- Queue notification deep link.
- Role switch.
- Logout reset.
- Dirty-form back confirmation.

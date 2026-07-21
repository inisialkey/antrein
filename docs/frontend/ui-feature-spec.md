# AntreIn — UI Feature Specification

> **Document:** `docs/frontend/ui-feature-spec.md`  
> **Status:** Draft v1.0  
> **Product Language:** Bahasa Indonesia  
> **Documentation Language:** English  
> **Document Language:** English  
> **Last Updated:** 2026-07-21

---

## 1. Purpose

This document defines the screens, components, states, actions, and acceptance criteria for the AntreIn Flutter MVP.

Visible copy examples may later be finalized in Bahasa Indonesia localization resources.

---

## 2. Design Direction

AntreIn should feel:

- Clear.
- Trustworthy.
- Modern.
- Friendly.
- Operationally efficient.
- Suitable for Indonesian local service businesses.

Avoid:

- Overly playful financial/payment UI.
- Excessive gradients.
- Dense enterprise tables on mobile.
- Hidden status.
- Ambiguous payment success.
- Queue screens that require repeated manual refresh.

---

## 3. Design System Foundations

### Typography

- Clear hierarchy.
- Large queue numbers.
- Readable payment values.
- Compact supporting metadata.

### Spacing

Recommended base scale:

```text
4, 8, 12, 16, 24, 32
```

### Radius

```text
small
medium
large
pill
```

### Semantic Status

```text
success
warning
error
info
neutral
```

Status must include icon/text, not color only.

---

## 4. Shared Components

- App bar.
- Bottom navigation.
- Primary button.
- Secondary button.
- Destructive button.
- Status chip.
- Money text.
- Date/time row.
- Service card.
- Staff card.
- Business card.
- Booking card.
- Queue card.
- Empty state.
- Error state.
- Offline banner.
- Skeleton loader.
- Confirmation bottom sheet.
- Form field.
- Search field.
- Filter sheet.
- Async action button.

---

# Customer Features

## 5. Splash Screen

Purpose:

- Initialize dependencies.
- Restore session.
- Resolve routing.

States:

```text
loading
recoverable initialization error
```

No business data should appear before session ownership is known.

---

## 6. Onboarding

MVP content:

- Book services easily.
- Avoid unnecessary waiting.
- Track queues in real time.

Actions:

- Continue.
- Skip.

Onboarding completion is non-sensitive local preference.

---

## 7. Login

Fields:

- Email.
- Password.

Actions:

- Login.
- Forgot password.
- Register.

States:

- Idle.
- Submitting.
- Invalid credentials.
- Rate limited.
- Network failure.

Password visibility toggle is allowed.

---

## 8. Registration

Fields:

- Name.
- Email.
- Phone number.
- Password.
- Password confirmation.

Validation:

- Inline.
- Backend remains authoritative.

Success:

- Session created.
- Navigate to customer home or role selection.

---

## 9. Forgot Password

Field:

- Email.

Success message must not reveal whether the account exists.

---

## 10. Customer Home

Sections:

- Greeting.
- Upcoming booking card.
- Active queue card.
- Search.
- Recommended or recent businesses.
- Popular services.
- Quick access to booking history.

States:

- Loading.
- Cached/stale data.
- Empty discovery.
- Error.
- Offline.

---

## 11. Business List

Features:

- Search.
- Sort.
- Pull to refresh.
- Pagination.

Business card:

- Logo/image.
- Name.
- Rating.
- Address.
- Open/closed state.
- Price range.
- Payment options.

---

## 12. Business Detail

Sections:

- Cover.
- Name and rating.
- Address.
- Operating hours.
- Service list.
- Staff list.
- Payment options.
- Cancellation summary.
- Reviews.

Primary action:

```text
Book Now
```

---

## 13. Service Selection

Service card:

- Name.
- Description.
- Duration.
- Price.
- Deposit information.
- Image.
- Selected state.

Only active services appear.

---

## 14. Staff Selection

Options:

- Any available staff.
- Specific staff.

Staff card:

- Photo.
- Name.
- Rating.
- Eligible service.
- Availability indication.

Availability remains informational.

---

## 15. Date and Slot Selection

Components:

- Horizontal date selector or calendar.
- Slot grid/list.
- Staff context.
- Service duration.
- Timezone context.

States:

- Loading.
- No slots.
- Error.
- Slot became unavailable after submission.

When conflict occurs:

```text
Clear selected slot
→ Refresh list
→ Explain that another customer booked it
```

---

## 16. Booking Review

Show:

- Business.
- Outlet.
- Service.
- Staff.
- Date/time.
- Duration.
- Price.
- Deposit/full amount.
- Cancellation policy.
- Notes.

Primary action:

```text
Continue to Payment
```

---

## 17. Payment Option Selection

Options:

- Pay at location.
- Pay in full.
- Deposit.

Each option shows:

- Amount required now.
- Remaining amount.
- Confirmation behavior.

Disabled options include explanation.

---

## 18. Booking Submission

While submitting:

- Disable duplicate taps.
- Keep idempotency key.
- Show progress.
- Do not navigate twice.

Failure states:

- Slot unavailable.
- Provider unavailable.
- Session expired.
- Validation error.

---

## 19. Payment Pending

Show:

- Required amount.
- Expiration countdown.
- Payment method/checkout action.
- Pending status.
- Refresh action.
- Booking summary.

Actions:

- Open checkout.
- Refresh status.
- Return to booking detail.

Do not show success until backend confirms.

---

## 20. Payment Result

### Paid

- Success icon.
- Amount.
- Confirmed booking.
- View booking action.

### Pending

- Explain verification delay.
- Continue listening.
- Refresh safely.

### Failed

- Reason when safe.
- Retry option if backend allows.

### Expired

- Explain slot release.
- Return to business.

---

## 21. Booking List

Tabs/filters:

```text
Upcoming
Completed
Cancelled
```

Card:

- Booking code.
- Business.
- Service.
- Date/time.
- Status.
- Payment summary.

Pagination supported.

---

## 22. Booking Detail

Sections:

- Status timeline.
- Business/outlet.
- Service/staff.
- Schedule.
- Payment.
- Cancellation policy.
- Queue state.
- Notes.

Server-provided actions:

- Pay.
- Cancel.
- Check in.
- View queue.
- Review.

---

## 23. Cancellation

Confirmation sheet shows:

- Reason.
- Refund estimate.
- Policy.
- Destructive action.

After success:

- Booking status.
- Refund state.
- Notification.

---

## 24. Check-In

Button appears only when server says eligible.

Confirmation:

- Current location/address context.
- Queue behavior.
- Check-in result.

Success:

- Queue number.
- People ahead.
- View live queue.

---

## 25. Customer Live Queue

Primary content:

- Large display number.
- Status.
- People ahead.
- Current number.
- Estimated wait.
- Service/staff.
- Last updated.
- Connection indicator.

States:

```text
waiting
called
in_service
completed
skipped/recovery message when relevant
```

Called state must be visually prominent and accessible.

---

## 26. Notifications

Features:

- Paginated list.
- Unread indicator.
- Mark read.
- Mark all read.
- Deep-link navigation.

Notification card:

- Icon.
- Title.
- Body.
- Time.
- Resource status.

---

## 27. Profile

Sections:

- User identity.
- Role switch.
- Notification preferences.
- Settings.
- Logout.

Sensitive account actions require confirmation.

---

## 28. Review Form

Eligibility:

- Completed booking.
- No existing review.

Fields:

- Rating 1–5.
- Optional comment.

Success returns to booking detail.

---

# Business Features

## 29. Business Dashboard

Summary cards:

- Today’s bookings.
- Waiting.
- In service.
- Completed.
- Pending payment.
- Gross paid.

Quick actions:

- Open queue.
- Add walk-in.
- View bookings.
- Manage services.

---

## 30. Business Booking List

Filters:

- Date.
- Status.
- Staff.
- Payment status.

Card:

- Booking code.
- Customer.
- Service.
- Schedule.
- Staff.
- Payment.
- Queue status.

---

## 31. Business Booking Detail

Operational sections:

- Customer identity.
- Service.
- Staff.
- Booking timeline.
- Payment summary.
- Queue state.
- Customer notes.
- Internal note.

Available actions:

- Check in.
- Mark no-show.
- Cancel.
- Confirm payment.
- Open queue entry.

---

## 32. Queue Dashboard

Layout:

- Current serving.
- Called.
- Waiting.
- Skipped.
- Completed count.

Entry card:

- Display number.
- Customer name.
- Service.
- Staff.
- Check-in time.
- Status.
- Available action.

Use compact operational actions.

---

## 33. Queue Actions

### Call

- Confirmation optional.
- Immediate pending indicator.
- Conflict refresh.

### Recall

- Show recall count.
- Prevent rapid accidental repeats.

### Skip

- Reason required or selected.
- Explain return behavior.

### Start Service

- Confirm staff.
- Validate latest version.

### Complete

- Show outstanding balance.
- Confirm completion.

### No-Show

- Destructive confirmation.
- Reason required.

---

## 34. Walk-In Form

Fields:

- Customer name.
- Optional phone.
- Service.
- Staff.
- Payment option.
- Notes.

Success:

- Queue number.
- Highlight entry in queue.

---

## 35. Service Management

List:

- Active/inactive status.
- Price.
- Duration.
- Deposit.
- Staff eligibility.

Create/edit form:

- Name.
- Description.
- Image.
- Duration.
- Price.
- Deposit.
- Eligible staff.
- Active state.

Historical bookings remain unaffected.

---

## 36. Staff Management

List:

- Avatar.
- Name.
- Role.
- Status.
- Assigned services.
- Outlet.

Actions:

- Invite.
- Edit.
- Deactivate.

Deactivation warnings must show active-booking impact from backend.

---

## 37. Schedule Management

Sections:

- Outlet operating hours.
- Staff schedule.
- Breaks.
- Closed dates.

Use clear day-by-day editing.

Overlapping periods show inline validation.

---

## 38. Business Settings

Sections:

- Profile.
- Outlet.
- Booking policy.
- Payment options.
- Deposit.
- Cancellation policy.
- Notification preferences.

Critical policy changes require confirmation.

---

## 39. Daily Report

Show:

- Total bookings.
- Completed.
- Cancelled.
- No-show.
- Average wait.
- Gross paid.
- Pending.
- Refunded.

MVP uses simple cards and summaries, not complex charts.

---

# Cross-Cutting UI States

## 40. Offline

Show persistent banner.

Allowed:

- View cached business data.
- View cached booking summary.

Blocked:

- Create booking.
- Payment refresh.
- Check-in.
- Queue command.
- Refund.

---

## 41. Session Expired

Behavior:

- Preserve non-sensitive pending intent where safe.
- Clear secure session.
- Show login.
- Restore pending deep link after login when valid.

---

## 42. Maintenance

Show:

- Service unavailable message.
- Retry.
- Status context.
- No fake success.

---

## 43. Permission Denied

Examples:

- Push permission.
- Photo permission.

Explain feature impact and provide settings action when appropriate.

---

## 44. Loading

Use:

- Skeleton for lists/cards.
- Button spinner for mutations.
- Full-screen loader only for initialization or blocking transition.

---

## 45. Empty States

Examples:

- No bookings.
- No notifications.
- No services.
- No staff.
- Empty queue.
- No slots.

Each empty state should offer one relevant next action.

---

## 46. Error Copy

Error copy should:

- Be user-readable.
- Avoid technical jargon.
- Offer next action.
- Avoid exposing provider or database internals.

---

## 47. Responsive Behavior

Primary target:

```text
Mobile portrait
```

Support:

- Small Android devices.
- Large phones.
- iPhone safe areas.
- Dynamic text.

Tablet optimization is secondary.

---

## 48. Accessibility Acceptance

- All interactive controls have semantic labels.
- Status is not color-only.
- Called queue state is announced.
- Forms expose errors.
- Text scaling does not clip critical content.
- Touch targets meet minimum size.
- Focus order is logical.

---

## 49. Feature Acceptance Checklist

Every screen must define:

- Initial state.
- Loading state.
- Success state.
- Empty state.
- Error state.
- Offline behavior.
- Permission behavior.
- Analytics event.
- Accessibility labels.
- Navigation result.
- Test coverage.

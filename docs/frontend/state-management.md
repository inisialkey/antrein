# AntreIn — Flutter State Management

> **Document:** `docs/frontend/state-management.md`  
> **Status:** Draft v1.0  
> **Primary Pattern:** Cubit  
> **Library:** flutter_bloc  
> **Document Language:** English  
> **Last Updated:** 2026-07-21

---

## 1. Purpose

This document defines state-management conventions for AntreIn Flutter.

It covers:

- State ownership.
- Cubit and Bloc selection.
- State shape.
- Request lifecycle.
- Form state.
- Pagination.
- Real-time events.
- Session state.
- Role state.
- Error handling.
- Testing.

---

## 2. Principles

- State has one clear owner.
- Start with Cubit.
- Use Bloc only for event-heavy concurrent behavior.
- Keep server state separate from temporary UI state.
- Avoid one global application state object.
- State transitions are immutable.
- Side effects are explicit.
- Loading does not erase useful existing data.
- Stable API error codes remain available.

---

## 3. Cubit vs Bloc

Use Cubit when:

- Operations are command-like.
- One action maps to one method.
- Event concurrency is simple.
- State transitions are direct.

Use Bloc when:

- Multiple asynchronous event sources interact.
- Event transformation matters.
- Debounce/restartable/droppable behavior is central.
- A clear event log improves understanding.

Likely Cubits:

```text
SessionCubit
RoleCubit
LoginCubit
BusinessListCubit
BookingDetailCubit
PaymentCubit
CustomerQueueCubit
BusinessQueueCubit
NotificationCubit
```

Possible Blocs:

```text
RealtimeConnectionBloc
ComplexBusinessQueueBloc
```

Only introduce Bloc if complexity is demonstrated.

---

## 4. State Shape

Prefer feature-specific immutable states.

Example:

```dart
@freezed
class BookingDetailState with _$BookingDetailState {
  const factory BookingDetailState({
    @Default(LoadStatus.initial) LoadStatus loadStatus,
    Booking? booking,
    AppFailure? failure,
    @Default(false) bool isRefreshing,
    @Default(false) bool isCancelling,
  }) = _BookingDetailState;
}
```

---

## 5. Load Status

Shared enum:

```text
initial
loading
success
empty
failure
```

Use separate action flags for mutations.

Avoid changing the entire screen to loading during refresh.

---

## 6. Server State vs UI State

Server state examples:

- Booking.
- Payment.
- Queue snapshot.
- Business list.

UI state examples:

- Selected tab.
- Search text.
- Expanded card.
- Form input.
- Temporary confirmation selection.

Do not persist temporary UI state as authoritative domain data.

---

## 7. Session State

Recommended:

```text
unknown
restoring
authenticated
refreshing
unauthenticated
expired
failure
```

SessionCubit owns:

- Current user.
- Token restoration result.
- Memberships.
- Authentication lifecycle.

Token interceptor does not navigate directly.

It reports session expiration to SessionCubit.

---

## 8. Role State

RoleCubit owns:

- Available roles.
- Active mode.
- Active business.
- Active outlet.
- Effective permissions.
- Role-switch lifecycle.

Role state is cleared on logout.

---

## 9. Form State

Use Cubit for multi-step or server-dependent forms.

Use local controllers for simple text editing.

The Cubit stores semantic values, not `TextEditingController`.

Example booking draft:

```text
business
service
staff selection
date
slot
notes
payment option
```

---

## 10. Booking Flow State

One BookingFlowCubit spans the booking steps.

Responsibilities:

- Load business context.
- Select service.
- Load eligible staff.
- Select staff.
- Load availability.
- Select slot.
- Select payment option.
- Submit booking.
- Reset on completion.

Selections invalidated by an earlier change must be cleared.

Example:

```text
Service changes
→ Clear staff
→ Clear date/slot
→ Recalculate payment
```

---

## 11. Mutation State

Each mutation tracks:

```text
idle
submitting
succeeded
failed
```

Repeated taps are disabled while submitting.

Idempotency key is created when logical submission begins and retained for retry.

---

## 12. Pagination State

Recommended fields:

```text
items
nextCursor
hasMore
isLoadingInitial
isLoadingMore
isRefreshing
failure
```

Rules:

- Do not clear items on load-more failure.
- Refresh replaces list after success.
- Avoid duplicate IDs when pages overlap.
- Cursor is opaque.

---

## 13. Search State

Search behavior:

- Local text updates immediately.
- Remote search is debounced.
- Previous request is cancelled or ignored.
- Empty query returns default discovery.
- Search failure preserves previous data when appropriate.

---

## 14. Error State

Store typed `AppFailure`.

UI maps:

- Error code.
- Context.
- Available action.

Example:

```text
BOOKING_SLOT_UNAVAILABLE
→ Clear selected slot
→ Refresh availability
→ Show conflict message
```

---

## 15. One-Time Effects

Avoid storing navigation commands permanently in state.

Options:

- BlocListener reacts to transition.
- Separate effect stream.
- State includes incrementing effect token.

Preferred MVP:

- Use `BlocListener` with status transitions.
- Reset transient success/error after handling when needed.

---

## 16. Realtime State

Feature Cubit receives typed events.

Example customer queue:

```text
REST snapshot version 5
→ Event version 6
→ Apply

Event version 9
→ Gap detected
→ Refetch
```

Never let WebSocket transport mutate UI state directly.

---

## 17. Realtime Connection State

```text
disconnected
connecting
connected
reconnecting
failed
```

Connection state is global infrastructure state.

Feature state remains usable with stale indicator during reconnect.

---

## 18. Customer Queue State

Recommended fields:

```text
queue
loadStatus
connectionStatus
isRefreshing
failure
lastSyncedAt
```

Behavior:

- REST loads initial state.
- WebSocket applies newer event.
- Resume refetches.
- Called event triggers visible emphasis.
- Completed event updates final state.

---

## 19. Business Queue State

Recommended fields:

```text
snapshot
selectedFilter
connectionStatus
pendingCommandIds
failure
lastSyncedAt
```

Commands use entry-specific pending state so one action does not block the entire queue.

---

## 20. Version Conflict

On `QUEUE_VERSION_CONFLICT`:

```text
Stop command loading
→ Refetch snapshot
→ Show “Queue changed, latest data loaded”
```

Do not automatically repeat the mutation.

---

## 21. Payment State

Recommended statuses:

```text
initial
creating
pending
paid
failed
expired
cancelled
refreshing
```

PaymentCubit owns:

- Payment representation.
- Backend polling/refresh.
- WebSocket updates.
- App-resume recovery.
- Checkout launch intent.

External checkout result never sets `paid`.

---

## 22. Notification State

NotificationCubit supports:

- Initial load.
- Pagination.
- Unread count.
- Mark one read.
- Mark all read.
- Foreground event insertion.
- Duplicate prevention.

---

## 23. Cache Hydration

A repository may emit cached data before remote data.

State behavior:

```text
Cached data
→ success with stale marker
→ remote refresh
→ replace or preserve on failure
```

Sensitive cached state is shown only after user ownership is resolved.

---

## 24. State Persistence

Persist only useful safe state:

- Last selected role.
- Non-sensitive onboarding completion.
- Cache metadata.
- User preferences.

Do not persist:

- Cubit instances.
- Pending payment success.
- Queue command state.
- Raw access tokens outside secure storage.

---

## 25. Cancellation and Disposal

Cubits must cancel:

- Debounce timers.
- Stream subscriptions.
- Pagination requests when disposed.
- Realtime feature subscriptions.
- Upload tasks when appropriate.

---

## 26. Concurrency

Examples:

### Login

Ignore repeated submit while active.

### Search

Use restartable behavior.

### Load More

Use droppable behavior.

### Queue Command

One pending command per entry.

### Refresh Token

Globally serialized outside feature Cubits.

---

## 27. Dependency Injection

Cubits receive:

- Use cases or repositories.
- Clock where needed.
- Analytics wrapper.
- Realtime event source when feature-specific.

Cubits do not locate dependencies directly through GetIt internally.

---

## 28. Testing

For each Cubit:

- Initial state.
- Loading.
- Success.
- Empty.
- Failure.
- Retry.
- Stale-data preservation.
- Error-code behavior.
- Realtime event.
- Out-of-order event.
- Disposal.

Use bloc_test where appropriate.

---

## 29. Naming

Examples:

```text
BookingFlowCubit
BookingFlowState
loadAvailability()
selectService()
submitBooking()
```

Avoid:

```text
BookingManager
setData()
process()
handleEverything()
```

---

## 30. Acceptance Criteria

- Each state has one owner.
- Cubit is default.
- Loading preserves useful data.
- Mutations prevent duplicate taps.
- Idempotency key lifecycle is correct.
- API failures are typed.
- Realtime events use versions.
- Version conflicts refetch instead of blind retry.
- Session and role state are centralized.
- Tests cover success, failure, and concurrency behavior.

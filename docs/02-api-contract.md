# AntreIn — API Contract

> **Document:** `docs/02-api-contract.md`  
> **Status:** Draft v1.0  
> **Product:** AntreIn  
> **API Style:** REST JSON over HTTPS  
> **Real-Time Transport:** Secure WebSocket  
> **API Version:** `v1`  
> **Primary Mobile Client:** Flutter  
> **Backend:** NestJS  
> **Document Language:** English  
> **Last Updated:** 2026-07-21

---

## 1. Document Purpose

This document defines the shared application contract between the AntreIn Flutter mobile application and the NestJS backend.

It specifies:

- Base URL and versioning.
- Request and response conventions.
- Authentication and authorization headers.
- Idempotency.
- Pagination.
- Date, time, currency, and identifier formats.
- Stable error codes.
- REST endpoints.
- Request and response schemas.
- Payment-webhook behavior.
- WebSocket connection and event contracts.
- Contract compatibility rules.
- Contract testing expectations.

This document is the human-readable contract. The backend-generated OpenAPI specification is the machine-readable contract.

When this document and generated OpenAPI differ, the mismatch must be treated as a contract defect and resolved before release.

---

## 2. Scope

This contract covers the MVP modules:

- Authentication.
- User profile.
- Device registration.
- Business discovery.
- Business management.
- Outlet management.
- Service management.
- Staff management.
- Operating hours and closed dates.
- Availability and slot discovery.
- Booking.
- Payment.
- Refund.
- Check-in.
- Queue management.
- Notifications.
- Reviews.
- Basic reporting.
- File uploads.
- Health checks.
- Payment-provider webhooks.

This contract does not cover:

- Full web administration.
- Subscription billing.
- Multi-currency.
- Multi-language API content negotiation.
- Chat.
- Loyalty.
- Inventory.
- Payroll.
- Marketplace settlements.
- Complex promotion engines.

---

## 3. Contract Principles

### 3.1 Backend Is Authoritative

The backend is authoritative for:

- Price.
- Deposit amount.
- Available slots.
- Staff eligibility.
- Booking status.
- Payment status.
- Queue number.
- Queue order.
- Refund eligibility.
- Permissions.

Flutter may submit user choices but never submits authoritative business outcomes.

### 3.2 Stable Product Error Codes

Flutter handles stable `error.code` values.

Flutter must not depend on:

- Raw exception messages.
- Stack traces.
- Database error names.
- Provider-specific payment messages.

### 3.3 Backward-Compatible Evolution

The `v1` contract should evolve through non-breaking changes whenever possible.

### 3.4 Idempotent Critical Mutations

Critical retryable mutations use the `Idempotency-Key` header.

### 3.5 Authoritative REST Recovery

WebSocket events improve responsiveness. REST remains the recovery and reconciliation path.

### 3.6 Privacy by Contract

Responses expose only data required by the authenticated user and active role.

---

## 4. Base URLs

### 4.1 Local

```text
http://localhost:3000/api/v1
```

Android emulator example:

```text
http://10.0.2.2:3000/api/v1
```

### 4.2 Development

```text
https://api.dev.antrein.example/api/v1
```

### 4.3 Staging

```text
https://api.staging.antrein.example/api/v1
```

### 4.4 Production

```text
https://api.antrein.example/api/v1
```

Final domains are environment configuration, not hardcoded application logic.

---

## 5. WebSocket URLs

### Local

```text
ws://localhost:3000/realtime
```

### Production-Like Environments

```text
wss://api.antrein.example/realtime
```

The final Socket.IO path and namespace must remain environment-configurable.

---

## 6. API Versioning

Versioning uses a URI prefix:

```text
/api/v1
```

A new major version is required for incompatible changes.

Examples of non-breaking changes:

- Adding an optional field.
- Adding an endpoint.
- Adding an optional query parameter.
- Adding an event type.
- Adding a response enum value only when clients are designed to tolerate unknown values.

Examples of breaking changes:

- Removing a field.
- Renaming a field.
- Changing a field type.
- Making an optional field required.
- Changing semantic meaning.
- Changing authorization rules incompatibly.
- Replacing cursor pagination with offset pagination.

---

## 7. Content Type and Encoding

Request and response bodies use:

```http
Content-Type: application/json
Accept: application/json
```

Encoding:

```text
UTF-8
```

File-upload endpoints use:

```http
Content-Type: multipart/form-data
```

---

## 8. Common Request Headers

### 8.1 Required for Authenticated Requests

```http
Authorization: Bearer <access-token>
```

### 8.2 Recommended Client Metadata

```http
X-Request-Id: req_client_generated_id
X-App-Version: 1.0.0
X-Platform: android
X-Device-Id: device_01...
```

Allowed platform values:

```text
android
ios
```

### 8.3 Idempotent Mutations

```http
Idempotency-Key: idem_01...
```

### 8.4 Optional Locale Header

The first MVP uses Bahasa Indonesia product copy, but the client may send:

```http
Accept-Language: id-ID
```

The API does not use localized messages as a stable contract. Error codes remain authoritative.

---

## 9. Common Response Headers

Recommended response headers:

```http
X-Request-Id: req_01...
X-API-Version: v1
```

Rate-limited endpoints may return:

```http
Retry-After: 60
```

---

## 10. Identifier Format

Public identifiers use opaque, globally unique strings.

Examples:

```text
usr_01J...
biz_01J...
out_01J...
svc_01J...
stf_01J...
bkg_01J...
pay_01J...
que_01J...
ntf_01J...
rev_01J...
fil_01J...
```

Clients must treat identifiers as opaque strings.

Clients must not:

- Parse identifiers.
- Infer creation time.
- Infer resource ownership.
- Generate authoritative resource IDs unless explicitly documented.

---

## 11. Date and Time Format

### 11.1 Timestamps

All timestamps use ISO 8601 with timezone offset or UTC.

Examples:

```text
2026-07-21T13:30:00+07:00
2026-07-21T06:30:00Z
```

### 11.2 Dates

Business dates use:

```text
YYYY-MM-DD
```

Example:

```text
2026-07-21
```

### 11.3 Local Times

Operating-hour values use:

```text
HH:mm
```

Example:

```text
09:00
```

### 11.4 Timezone

Timezone names use IANA identifiers.

Example:

```text
Asia/Jakarta
```

---

## 12. Monetary Format

Monetary values use integer IDR units.

Example:

```json
{
  "amount": 50000,
  "currency": "IDR"
}
```

Floating-point values are not allowed for money.

---

## 13. Boolean and Nullability Rules

- Boolean values use `true` or `false`.
- Missing optional field means the client did not provide it.
- Explicit `null` is accepted only when the schema documents nullable behavior.
- Empty strings must not be used as substitutes for `null`.

---

## 14. Enum Handling

Enum values use lowercase `snake_case`.

Examples:

```text
pending_payment
in_service
pay_at_location
```

Flutter should map known values to typed enums.

For forward compatibility, generated or handwritten clients should have an `unknown` fallback where practical.

---

## 15. Success Response Envelope

Single-resource response:

```json
{
  "success": true,
  "data": {
    "id": "bkg_01J..."
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

No-content action may still return a minimal data object:

```json
{
  "success": true,
  "data": {
    "acknowledged": true
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

---

## 16. Collection Response Envelope

```json
{
  "success": true,
  "data": {
    "items": []
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00",
    "pagination": {
      "nextCursor": null,
      "hasMore": false,
      "limit": 20
    }
  }
}
```

---

## 17. Error Response Envelope

```json
{
  "success": false,
  "error": {
    "code": "BOOKING_SLOT_UNAVAILABLE",
    "message": "The selected time slot is no longer available.",
    "details": {
      "staffId": "stf_01J...",
      "scheduledAt": "2026-07-22T10:00:00+07:00"
    }
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

Rules:

- `error.code` is stable.
- `error.message` is user-readable but not a client logic key.
- `error.details` is optional.
- Production responses never expose stack traces.
- Validation errors may include field-level details.

---

## 18. Validation Error Format

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "One or more fields are invalid.",
    "details": {
      "fields": [
        {
          "field": "email",
          "code": "INVALID_EMAIL",
          "message": "Enter a valid email address."
        },
        {
          "field": "password",
          "code": "MIN_LENGTH",
          "message": "Password must contain at least 8 characters."
        }
      ]
    }
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

---

## 19. HTTP Status Code Rules

| Status | Usage |
|---|---|
| `200 OK` | Successful read or action |
| `201 Created` | Resource created |
| `202 Accepted` | Asynchronous action accepted |
| `400 Bad Request` | Invalid request or malformed input |
| `401 Unauthorized` | Missing, invalid, or expired authentication |
| `403 Forbidden` | Authenticated but not permitted |
| `404 Not Found` | Resource not found or intentionally hidden |
| `409 Conflict` | State conflict or duplicate operation |
| `410 Gone` | Resource intentionally expired or no longer usable |
| `422 Unprocessable Entity` | Semantically invalid business request |
| `429 Too Many Requests` | Rate limit exceeded |
| `500 Internal Server Error` | Unexpected server failure |
| `502 Bad Gateway` | External provider failure |
| `503 Service Unavailable` | Temporary service unavailability |

---

## 20. Pagination

### 20.1 Cursor Pagination

Query:

```http
GET /bookings?limit=20&cursor=cursor_value
```

Response:

```json
{
  "success": true,
  "data": {
    "items": []
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00",
    "pagination": {
      "nextCursor": "cursor_next",
      "hasMore": true,
      "limit": 20
    }
  }
}
```

### 20.2 Limits

Default:

```text
20
```

Maximum:

```text
100
```

The backend may enforce a smaller endpoint-specific maximum.

### 20.3 Cursor Rules

- Cursor is opaque.
- Client does not decode it.
- Invalid cursor returns `VALIDATION_INVALID_CURSOR`.
- Changing sort or filter invalidates previous cursor assumptions.

---

## 21. Sorting

Query format:

```http
GET /businesses?sort=rating_desc
```

Supported sort values are endpoint-specific.

The API does not accept arbitrary database column names.

---

## 22. Filtering

Filters use explicit query parameters.

Example:

```http
GET /bookings?status=confirmed&dateFrom=2026-07-01&dateTo=2026-07-31
```

Multiple values may use comma-separated values only where documented.

Example:

```http
GET /bookings?status=confirmed,completed
```

---

## 23. Idempotency

### 23.1 Required Header

Critical supported mutations require:

```http
Idempotency-Key: idem_01J...
```

### 23.2 Behavior

Same key and same request:

- Returns original result.
- Does not repeat business effects.

Same key and different request:

- Returns `409 Conflict`.
- Error code: `IDEMPOTENCY_KEY_REUSED`.

Concurrent requests with same key:

- Only one operation executes.
- Others receive original result or processing conflict.

### 23.3 Retention

Idempotency records are retained for an endpoint-specific period.

MVP retention (ADR 0034):

```text
24 hours — general mutations (booking create, check-in, business/service management)
7 days   — payment actions (create payment, refund request, pay-at-location confirmation)
```

Webhook dedupe records (`payment_events`, unique per provider event ID) are permanent business records, outside this cleanup.

### 23.4 Request Fingerprint

The server derives a request fingerprint from:

- Authenticated principal.
- Endpoint/action.
- Relevant request body.
- Relevant route parameters.

---

## 24. Authentication Model

### 24.1 Access Token

Used for:

- REST requests.
- WebSocket authentication.

### 24.2 Refresh Token

Used only at the refresh endpoint.

### 24.3 Active Role

A user may have multiple roles.

The active business context is provided through route ownership or an explicit header only if later required.

MVP preference:

- Customer endpoints infer customer context.
- Business endpoints include `businessId` or `outletId` in the route.
- Backend validates membership.

---

# Part I — Authentication and User APIs

## 25. Register

```http
POST /auth/register
```

Authentication:

```text
Public
```

Request:

```json
{
  "name": "Oki",
  "email": "oki@example.com",
  "phoneNumber": "+6281234567890",
  "password": "StrongPassword123!"
}
```

Validation:

- `name`: required, 2–100 characters.
- `email`: valid and unique.
- `phoneNumber`: optional in early MVP, valid when provided.
- `password`: 8–128 characters, length-only (no composition rules) — ADR 0034.

Response `201`:

```json
{
  "success": true,
  "data": {
    "user": {
      "id": "usr_01J...",
      "name": "Oki",
      "email": "oki@example.com",
      "phoneNumber": "+6281234567890",
      "avatarUrl": null,
      "status": "active",
      "roles": [
        "customer"
      ],
      "createdAt": "2026-07-21T13:30:00+07:00"
    },
    "session": {
      "accessToken": "access-token",
      "accessTokenExpiresAt": "2026-07-21T13:45:00+07:00",
      "refreshToken": "refresh-token",
      "refreshTokenExpiresAt": "2026-08-20T13:30:00+07:00"
    }
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

Errors:

- `AUTH_EMAIL_ALREADY_REGISTERED`
- `AUTH_PHONE_ALREADY_REGISTERED`
- `VALIDATION_FAILED`
- `RATE_LIMIT_EXCEEDED`

---

## 26. Login

```http
POST /auth/login
```

Authentication:

```text
Public
```

Request:

```json
{
  "email": "oki@example.com",
  "password": "StrongPassword123!",
  "device": {
    "deviceId": "device_01J...",
    "platform": "android",
    "appVersion": "1.0.0",
    "deviceName": "Pixel 9"
  }
}
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "user": {
      "id": "usr_01J...",
      "name": "Oki",
      "email": "oki@example.com",
      "phoneNumber": "+6281234567890",
      "avatarUrl": null,
      "status": "active",
      "roles": [
        "customer",
        "business_owner"
      ],
      "businessMemberships": [
        {
          "businessId": "biz_01J...",
          "businessName": "AntreIn Barbershop",
          "role": "owner",
          "outletIds": [
            "out_01J..."
          ]
        }
      ]
    },
    "session": {
      "accessToken": "access-token",
      "accessTokenExpiresAt": "2026-07-21T13:45:00+07:00",
      "refreshToken": "refresh-token",
      "refreshTokenExpiresAt": "2026-08-20T13:30:00+07:00"
    }
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

Errors:

- `AUTH_INVALID_CREDENTIALS`
- `AUTH_ACCOUNT_INACTIVE`
- `AUTH_ACCOUNT_SUSPENDED`
- `RATE_LIMIT_EXCEEDED`

---

## 27. Refresh Session

```http
POST /auth/refresh
```

Authentication:

```text
Refresh token in request body
```

Request:

```json
{
  "refreshToken": "refresh-token",
  "deviceId": "device_01J..."
}
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "accessToken": "new-access-token",
    "accessTokenExpiresAt": "2026-07-21T14:00:00+07:00",
    "refreshToken": "new-refresh-token",
    "refreshTokenExpiresAt": "2026-08-20T13:45:00+07:00"
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:45:00+07:00"
  }
}
```

Errors:

- `AUTH_REFRESH_TOKEN_INVALID`
- `AUTH_REFRESH_TOKEN_EXPIRED`
- `AUTH_SESSION_REVOKED`
- `AUTH_REFRESH_TOKEN_REUSED`

---

## 28. Logout Current Session

```http
POST /auth/logout
```

Authentication:

```text
Bearer token required
```

Request:

```json
{
  "refreshToken": "refresh-token",
  "deviceId": "device_01J..."
}
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "loggedOut": true
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

---

## 29. Request Password Reset

```http
POST /auth/password/forgot
```

Authentication:

```text
Public
```

Request:

```json
{
  "email": "oki@example.com"
}
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "accepted": true
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

The response must not reveal whether the account exists.

---

## 30. Reset Password

```http
POST /auth/password/reset
```

Authentication:

```text
Public reset token
```

Request:

```json
{
  "token": "password-reset-token",
  "newPassword": "NewStrongPassword123!"
}
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "passwordReset": true,
    "allSessionsRevoked": true
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

Errors:

- `AUTH_RESET_TOKEN_INVALID`
- `AUTH_RESET_TOKEN_EXPIRED`
- `AUTH_PASSWORD_REUSE_NOT_ALLOWED`

---

## 31. Get Current User

```http
GET /me
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "id": "usr_01J...",
    "name": "Oki",
    "email": "oki@example.com",
    "phoneNumber": "+6281234567890",
    "avatarUrl": null,
    "status": "active",
    "roles": [
      "customer",
      "business_owner"
    ],
    "businessMemberships": [
      {
        "businessId": "biz_01J...",
        "businessName": "AntreIn Barbershop",
        "role": "owner",
        "permissions": [
          "business.manage",
          "service.manage",
          "staff.manage",
          "booking.read",
          "queue.manage",
          "payment.confirm"
        ],
        "outletIds": [
          "out_01J..."
        ]
      }
    ],
    "notificationPreferences": {
      "bookingUpdates": true,
      "paymentUpdates": true,
      "queueUpdates": true,
      "marketing": false
    },
    "createdAt": "2026-07-21T13:30:00+07:00",
    "updatedAt": "2026-07-21T13:30:00+07:00"
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

---

## 32. Update Current User

```http
PATCH /me
```

Request:

```json
{
  "name": "Oki Key",
  "phoneNumber": "+6281234567890",
  "avatarFileId": "fil_01J..."
}
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "id": "usr_01J...",
    "name": "Oki Key",
    "email": "oki@example.com",
    "phoneNumber": "+6281234567890",
    "avatarUrl": "https://cdn.example/avatar.jpg",
    "updatedAt": "2026-07-21T13:30:00+07:00"
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

Errors:

- `USER_PHONE_ALREADY_USED`
- `FILE_NOT_FOUND`
- `FILE_NOT_OWNED`
- `VALIDATION_FAILED`

---

## 33. Update Notification Preferences

```http
PATCH /me/notification-preferences
```

Request:

```json
{
  "bookingUpdates": true,
  "paymentUpdates": true,
  "queueUpdates": true,
  "marketing": false
}
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "bookingUpdates": true,
    "paymentUpdates": true,
    "queueUpdates": true,
    "marketing": false,
    "updatedAt": "2026-07-21T13:30:00+07:00"
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

---

## 34. Register Device

```http
PUT /me/devices/{deviceId}
```

Idempotency:

```text
Naturally idempotent by deviceId
```

Request:

```json
{
  "platform": "android",
  "appVersion": "1.0.0",
  "pushToken": "provider-device-token",
  "pushProvider": "onesignal",
  "deviceName": "Pixel 9",
  "locale": "id-ID",
  "timezone": "Asia/Jakarta"
}
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "deviceId": "device_01J...",
    "registered": true,
    "updatedAt": "2026-07-21T13:30:00+07:00"
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

---

## 35. Remove Device

```http
DELETE /me/devices/{deviceId}
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "removed": true
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

---

# Part II — File APIs

## 36. Upload File

```http
POST /files
```

Authentication:

```text
Bearer token required
```

Content type:

```http
multipart/form-data
```

Form fields:

```text
file
purpose
```

Allowed `purpose` values:

```text
customer_avatar
business_logo
business_gallery
staff_avatar
service_image
```

Limits (ADR 0034): max 5 MB per file; JPEG, PNG, WebP only; max 10 `business_gallery` images per business.

Response `201`:

```json
{
  "success": true,
  "data": {
    "id": "fil_01J...",
    "purpose": "customer_avatar",
    "mimeType": "image/jpeg",
    "size": 182340,
    "status": "ready",
    "url": "https://cdn.example/file.jpg",
    "createdAt": "2026-07-21T13:30:00+07:00"
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

Errors:

- `FILE_TOO_LARGE`
- `FILE_TYPE_NOT_ALLOWED`
- `FILE_INVALID_CONTENT`
- `FILE_UPLOAD_FAILED`

---

## 37. Delete Unattached File

```http
DELETE /files/{fileId}
```

Only an owned, unattached file may be deleted through this endpoint.

Response `200`:

```json
{
  "success": true,
  "data": {
    "deleted": true
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

Errors:

- `FILE_NOT_FOUND`
- `FILE_NOT_OWNED`
- `FILE_ALREADY_ATTACHED`

---

## 37.1 Serve File Content

```http
GET /files/{fileId}/content
```

Authentication:

```text
None — the opaque file id is the access control (ADR 0046)
```

Every `*Url` field in this contract (`avatarUrl`, `logoUrl`, `imageUrl`) is this
endpoint's absolute URL for the file id the resource points at.

Response `200` is the raw image, not the JSON envelope:

```http
Content-Type: image/jpeg | image/png | image/webp
Cache-Control: public, max-age=31536000, immutable
```

Errors:

- `FILE_NOT_FOUND` — unknown, deleted, or unreadable from storage

---

# Part III — Business Discovery APIs

## 38. List Businesses

```http
GET /businesses
```

Authentication:

```text
Optional for public discovery; authenticated requests may receive personalized fields later
```

Query parameters:

```text
q
serviceId
latitude
longitude
radiusKm
sort
cursor
limit
```

> `latitude`, `longitude`, `radiusKm` are **reserved** in v1: accepted but not evaluated
> (map/distance discovery is post-MVP). Sending them is not an error — ADR 0034.

MVP supported sort values:

```text
recommended
rating_desc
name_asc
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "biz_01J...",
        "name": "AntreIn Barbershop",
        "slug": "antrein-barbershop",
        "logoUrl": "https://cdn.example/logo.jpg",
        "coverImageUrl": "https://cdn.example/cover.jpg",
        "rating": {
          "average": 4.8,
          "count": 124
        },
        "primaryOutlet": {
          "id": "out_01J...",
          "name": "Main Outlet",
          "address": {
            "formatted": "Jl. Example No. 10, Jakarta",
            "latitude": -6.2,
            "longitude": 106.8
          },
          "timezone": "Asia/Jakarta",
          "isOpenNow": true
        },
        "priceRange": {
          "minimum": {
            "amount": 30000,
            "currency": "IDR"
          },
          "maximum": {
            "amount": 100000,
            "currency": "IDR"
          }
        },
        "supportedPaymentOptions": [
          "pay_at_location",
          "full_payment",
          "deposit"
        ]
      }
    ]
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00",
    "pagination": {
      "nextCursor": null,
      "hasMore": false,
      "limit": 20
    }
  }
}
```

---

## 39. Get Business Details

```http
GET /businesses/{businessId}
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "id": "biz_01J...",
    "name": "AntreIn Barbershop",
    "slug": "antrein-barbershop",
    "description": "Modern barbershop with online booking.",
    "logoUrl": "https://cdn.example/logo.jpg",
    "gallery": [
      {
        "id": "fil_01J...",
        "url": "https://cdn.example/gallery.jpg"
      }
    ],
    "status": "active",
    "rating": {
      "average": 4.8,
      "count": 124
    },
    "supportedPaymentOptions": [
      "pay_at_location",
      "full_payment",
      "deposit"
    ],
    "bookingPolicy": {
      "minimumLeadMinutes": 60,
      "maximumAdvanceDays": 30,
      "automaticConfirmation": true
    },
    "cancellationPolicy": {
      "summary": "Full refund is available until 6 hours before the appointment."
    },
    "outlets": [
      {
        "id": "out_01J...",
        "name": "Main Outlet",
        "phoneNumber": "+622112345678",
        "address": {
          "formatted": "Jl. Example No. 10, Jakarta",
          "latitude": -6.2,
          "longitude": 106.8
        },
        "timezone": "Asia/Jakarta",
        "operatingHours": [
          {
            "dayOfWeek": "monday",
            "isClosed": false,
            "periods": [
              {
                "opensAt": "09:00",
                "closesAt": "21:00"
              }
            ]
          }
        ]
      }
    ],
    "createdAt": "2026-07-21T13:30:00+07:00",
    "updatedAt": "2026-07-21T13:30:00+07:00"
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

Errors:

- `BUSINESS_NOT_FOUND`
- `BUSINESS_NOT_ACTIVE`

---

## 40. List Business Services

```http
GET /businesses/{businessId}/services
```

Query:

```text
outletId
staffId
activeOnly
cursor
limit
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "svc_01J...",
        "businessId": "biz_01J...",
        "name": "Haircut",
        "description": "Standard haircut service.",
        "imageUrl": "https://cdn.example/service.jpg",
        "durationMinutes": 45,
        "price": {
          "amount": 50000,
          "currency": "IDR"
        },
        "deposit": {
          "type": "fixed",
          "value": 10000,
          "requiredAmount": {
            "amount": 10000,
            "currency": "IDR"
          }
        },
        "isActive": true
      }
    ]
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00",
    "pagination": {
      "nextCursor": null,
      "hasMore": false,
      "limit": 20
    }
  }
}
```

---

## 41. List Business Staff

```http
GET /businesses/{businessId}/staff
```

Query:

```text
outletId
serviceId
date
activeOnly
cursor
limit
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "stf_01J...",
        "userId": "usr_01J...",
        "name": "Andi",
        "avatarUrl": "https://cdn.example/staff.jpg",
        "role": "barber",
        "isActive": true,
        "rating": {
          "average": 4.9,
          "count": 80
        },
        "eligibleServiceIds": [
          "svc_01J..."
        ]
      }
    ]
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00",
    "pagination": {
      "nextCursor": null,
      "hasMore": false,
      "limit": 20
    }
  }
}
```

---

## 42. Get Available Slots

```http
GET /businesses/{businessId}/availability
```

Required query parameters:

```text
outletId
serviceId
date
```

Optional:

```text
staffId
```

Example:

```http
GET /businesses/biz_01J/availability?outletId=out_01J&serviceId=svc_01J&staffId=stf_01J&date=2026-07-22
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "businessId": "biz_01J...",
    "outletId": "out_01J...",
    "service": {
      "id": "svc_01J...",
      "name": "Haircut",
      "durationMinutes": 45
    },
    "staffSelection": {
      "mode": "specific_staff",
      "staffId": "stf_01J..."
    },
    "date": "2026-07-22",
    "timezone": "Asia/Jakarta",
    "slots": [
      {
        "startsAt": "2026-07-22T09:00:00+07:00",
        "endsAt": "2026-07-22T09:45:00+07:00",
        "available": true
      },
      {
        "startsAt": "2026-07-22T09:45:00+07:00",
        "endsAt": "2026-07-22T10:30:00+07:00",
        "available": false
      }
    ],
    "generatedAt": "2026-07-21T13:30:00+07:00"
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

Important:

- Availability is informational.
- The backend revalidates during booking creation.
- An available slot is not reserved until booking creation succeeds.

Errors:

- `BUSINESS_NOT_FOUND`
- `OUTLET_NOT_FOUND`
- `SERVICE_NOT_FOUND`
- `STAFF_NOT_FOUND`
- `STAFF_NOT_ELIGIBLE_FOR_SERVICE`
- `SCHEDULE_DATE_OUT_OF_RANGE`

---

# Part IV — Business Management APIs

## 43. Create Business

```http
POST /businesses
```

Authentication:

```text
Bearer token required
```

Idempotency:

```text
Required
```

Request:

```json
{
  "name": "AntreIn Barbershop",
  "description": "Modern barbershop with online booking.",
  "logoFileId": "fil_01J...",
  "timezone": "Asia/Jakarta",
  "primaryOutlet": {
    "name": "Main Outlet",
    "phoneNumber": "+622112345678",
    "address": {
      "formatted": "Jl. Example No. 10, Jakarta",
      "latitude": -6.2,
      "longitude": 106.8
    }
  }
}
```

Response `201`:

```json
{
  "success": true,
  "data": {
    "id": "biz_01J...",
    "name": "AntreIn Barbershop",
    "status": "active",
    "ownerUserId": "usr_01J...",
    "primaryOutlet": {
      "id": "out_01J...",
      "name": "Main Outlet"
    },
    "createdAt": "2026-07-21T13:30:00+07:00"
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

Errors:

- `BUSINESS_LIMIT_REACHED`
- `FILE_NOT_OWNED`
- `VALIDATION_FAILED`

---

## 44. Get Managed Business

```http
GET /businesses/{businessId}/management
```

Authorization:

```text
Business membership required
```

Response includes management-only fields:

```json
{
  "success": true,
  "data": {
    "id": "biz_01J...",
    "name": "AntreIn Barbershop",
    "description": "Modern barbershop with online booking.",
    "status": "active",
    "logoUrl": "https://cdn.example/logo.jpg",
    "timezone": "Asia/Jakarta",
    "supportedPaymentOptions": [
      "pay_at_location",
      "full_payment",
      "deposit"
    ],
    "bookingPolicy": {
      "minimumLeadMinutes": 60,
      "maximumAdvanceDays": 30,
      "automaticConfirmation": true,
      "maxActiveBookingsPerCustomer": 3,
      "checkInEarlyMinutes": 30,
      "checkInLateMinutes": 15
    },
    "depositPolicy": {
      "enabled": true,
      "defaultType": "fixed",
      "defaultValue": 10000
    },
    "cancellationPolicy": {
      "fullRefundBeforeMinutes": 360,
      "partialRefundBeforeMinutes": 120,
      "partialRefundPercentage": 50,
      "noShowRefundPercentage": 0
    },
    "createdAt": "2026-07-21T13:30:00+07:00",
    "updatedAt": "2026-07-21T13:30:00+07:00"
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

---

## 45. Update Business

```http
PATCH /businesses/{businessId}
```

Authorization:

```text
business.manage
```

Request:

```json
{
  "name": "AntreIn Premium Barbershop",
  "description": "Updated description.",
  "logoFileId": "fil_01J...",
  "supportedPaymentOptions": [
    "pay_at_location",
    "deposit"
  ],
  "bookingPolicy": {
    "minimumLeadMinutes": 120,
    "maximumAdvanceDays": 30,
    "automaticConfirmation": true
  },
  "depositPolicy": {
    "enabled": true,
    "defaultType": "fixed",
    "defaultValue": 15000
  },
  "cancellationPolicy": {
    "fullRefundBeforeMinutes": 360,
    "partialRefundBeforeMinutes": 120,
    "partialRefundPercentage": 50,
    "noShowRefundPercentage": 0
  }
}
```

Response `200` returns updated management representation.

Errors:

- `FORBIDDEN_BUSINESS_RESOURCE`
- `BUSINESS_NOT_FOUND`
- `FILE_NOT_OWNED`
- `PAYMENT_OPTION_NOT_SUPPORTED`
- `VALIDATION_FAILED`

---

## 46. Update Outlet

```http
PATCH /businesses/{businessId}/outlets/{outletId}
```

Authorization:

```text
business.manage
```

Request:

```json
{
  "name": "Main Outlet",
  "phoneNumber": "+622112345678",
  "timezone": "Asia/Jakarta",
  "address": {
    "formatted": "Jl. Updated No. 20, Jakarta",
    "latitude": -6.201,
    "longitude": 106.801
  }
}
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "id": "out_01J...",
    "businessId": "biz_01J...",
    "name": "Main Outlet",
    "phoneNumber": "+622112345678",
    "timezone": "Asia/Jakarta",
    "address": {
      "formatted": "Jl. Updated No. 20, Jakarta",
      "latitude": -6.201,
      "longitude": 106.801
    },
    "updatedAt": "2026-07-21T13:30:00+07:00"
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

---

# Part V — Service Management APIs

## 47. Create Service

```http
POST /businesses/{businessId}/services
```

Authorization:

```text
service.manage
```

Idempotency:

```text
Required
```

Request:

```json
{
  "name": "Haircut",
  "description": "Standard haircut service.",
  "imageFileId": "fil_01J...",
  "durationMinutes": 45,
  "price": {
    "amount": 50000,
    "currency": "IDR"
  },
  "deposit": {
    "type": "fixed",
    "value": 10000
  },
  "eligibleStaffIds": [
    "stf_01J..."
  ],
  "isActive": true
}
```

Allowed deposit types:

```text
none
fixed
percentage
```

Response `201`:

```json
{
  "success": true,
  "data": {
    "id": "svc_01J...",
    "businessId": "biz_01J...",
    "name": "Haircut",
    "description": "Standard haircut service.",
    "imageUrl": "https://cdn.example/service.jpg",
    "durationMinutes": 45,
    "price": {
      "amount": 50000,
      "currency": "IDR"
    },
    "deposit": {
      "type": "fixed",
      "value": 10000,
      "requiredAmount": {
        "amount": 10000,
        "currency": "IDR"
      }
    },
    "eligibleStaffIds": [
      "stf_01J..."
    ],
    "isActive": true,
    "createdAt": "2026-07-21T13:30:00+07:00"
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

Errors:

- `SERVICE_NAME_ALREADY_EXISTS`
- `SERVICE_INVALID_DURATION`
- `SERVICE_INVALID_PRICE`
- `SERVICE_INVALID_DEPOSIT`
- `STAFF_NOT_FOUND`
- `STAFF_NOT_IN_BUSINESS`

---

## 48. Update Service

```http
PATCH /businesses/{businessId}/services/{serviceId}
```

Authorization:

```text
service.manage
```

Request uses the same optional fields as create.

Response `200` returns updated service.

Historical booking snapshots remain unchanged.

---

## 49. Deactivate Service

```http
POST /businesses/{businessId}/services/{serviceId}/deactivate
```

Authorization:

```text
service.manage
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "id": "svc_01J...",
    "isActive": false,
    "deactivatedAt": "2026-07-21T13:30:00+07:00"
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

---

# Part VI — Staff Management APIs

## 50. Invite Staff

```http
POST /businesses/{businessId}/staff/invitations
```

Authorization:

```text
staff.manage
```

Idempotency:

```text
Required
```

Request:

```json
{
  "email": "andi@example.com",
  "displayName": "Andi",
  "role": "barber",
  "outletIds": [
    "out_01J..."
  ],
  "permissions": [
    "booking.read",
    "queue.manage",
    "payment.confirm"
  ],
  "eligibleServiceIds": [
    "svc_01J..."
  ]
}
```

Response `201`:

```json
{
  "success": true,
  "data": {
    "invitationId": "inv_01J...",
    "email": "andi@example.com",
    "status": "pending",
    "expiresAt": "2026-07-28T13:30:00+07:00"
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

Errors:

- `STAFF_ALREADY_MEMBER`
- `STAFF_INVITATION_ALREADY_PENDING`
- `OUTLET_NOT_IN_BUSINESS`
- `SERVICE_NOT_IN_BUSINESS`

---

## 51. Accept Staff Invitation

```http
POST /staff/invitations/{invitationId}/accept
```

Authorization:

```text
Bearer token required
```

Idempotency:

```text
Required
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "staffId": "stf_01J...",
    "businessId": "biz_01J...",
    "role": "barber",
    "status": "active"
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

Errors:

- `STAFF_INVITATION_NOT_FOUND` — unknown invitation, revoked invitation, or an invitation addressed to a different email
- `STAFF_INVITATION_EXPIRED`
- `STAFF_ALREADY_MEMBER`

---

## 52. Update Staff

```http
PATCH /businesses/{businessId}/staff/{staffId}
```

Authorization:

```text
staff.manage
```

Request:

```json
{
  "displayName": "Andi",
  "role": "barber",
  "avatarFileId": "fil_01J...",
  "outletIds": [
    "out_01J..."
  ],
  "permissions": [
    "booking.read",
    "queue.manage",
    "payment.confirm"
  ],
  "eligibleServiceIds": [
    "svc_01J..."
  ],
  "isActive": true
}
```

Response `200` returns updated staff representation.

---

## 53. Deactivate Staff

```http
POST /businesses/{businessId}/staff/{staffId}/deactivate
```

Authorization:

```text
staff.manage
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "id": "stf_01J...",
    "status": "inactive",
    "deactivatedAt": "2026-07-21T13:30:00+07:00"
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

Errors:

- `STAFF_HAS_ACTIVE_BOOKINGS`
- `STAFF_NOT_FOUND`
- `FORBIDDEN_BUSINESS_RESOURCE`

Policy (ADR 0036): deactivation is blocked while the staff member has future bookings in blocking statuses — `409 STAFF_HAS_ACTIVE_BOOKINGS` with the blocking booking ids in `error.details`. Resolve those bookings first.

---

# Part VII — Schedule Management APIs

## 54. Get Outlet Operating Hours

```http
GET /businesses/{businessId}/outlets/{outletId}/operating-hours
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "timezone": "Asia/Jakarta",
    "days": [
      {
        "dayOfWeek": "monday",
        "isClosed": false,
        "periods": [
          {
            "opensAt": "09:00",
            "closesAt": "21:00"
          }
        ]
      }
    ]
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

---

## 55. Replace Outlet Operating Hours

```http
PUT /businesses/{businessId}/outlets/{outletId}/operating-hours
```

Authorization:

```text
business.manage
```

Request:

```json
{
  "timezone": "Asia/Jakarta",
  "days": [
    {
      "dayOfWeek": "monday",
      "isClosed": false,
      "periods": [
        {
          "opensAt": "09:00",
          "closesAt": "21:00"
        }
      ]
    },
    {
      "dayOfWeek": "tuesday",
      "isClosed": true,
      "periods": []
    }
  ]
}
```

Response `200` returns normalized schedule.

Errors:

- `SCHEDULE_OVERLAPPING_PERIODS`
- `SCHEDULE_INVALID_PERIOD`
- `SCHEDULE_INVALID_TIMEZONE`

---

## 56. List Closed Dates

```http
GET /businesses/{businessId}/outlets/{outletId}/closed-dates
```

Query:

```text
dateFrom
dateTo
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "cld_01J...",
        "date": "2026-08-17",
        "reason": "Public holiday"
      }
    ]
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

---

## 57. Create Closed Date

```http
POST /businesses/{businessId}/outlets/{outletId}/closed-dates
```

Authorization:

```text
business.manage
```

Idempotency:

```text
Required
```

Request:

```json
{
  "date": "2026-08-17",
  "reason": "Public holiday"
}
```

Response `201` returns created record.

Errors:

- `SCHEDULE_CLOSED_DATE_ALREADY_EXISTS`
- `SCHEDULE_DATE_IN_PAST`
- `SCHEDULE_AFFECTS_EXISTING_BOOKINGS`

The exact behavior for existing bookings must be decided before implementation.

---

## 58. Get Staff Schedule

```http
GET /businesses/{businessId}/staff/{staffId}/schedule
```

Authorization:

```text
Business membership required
```

Response `200` uses the same normalized body as §58.1. A staff member whose
schedule was never configured returns all seven days with `isAvailable: false`
— availability then follows outlet operating hours until the first replace.

Errors:

- `STAFF_NOT_FOUND`

---

## 58.1. Replace Staff Schedule

```http
PUT /businesses/{businessId}/staff/{staffId}/schedule
```

Authorization:

```text
staff.manage
```

Request:

```json
{
  "timezone": "Asia/Jakarta",
  "days": [
    {
      "dayOfWeek": "monday",
      "isAvailable": true,
      "periods": [
        {
          "startsAt": "09:00",
          "endsAt": "17:00"
        }
      ],
      "breaks": [
        {
          "startsAt": "12:00",
          "endsAt": "13:00"
        }
      ]
    }
  ]
}
```

Response `200` returns normalized staff schedule.

---

# Part VIII — Booking APIs

## 59. Booking Resource

Canonical booking representation:

```json
{
  "id": "bkg_01J...",
  "bookingCode": "ANT-20260722-0012",
  "type": "scheduled",
  "status": "confirmed",
  "customer": {
    "id": "usr_01J...",
    "name": "Oki",
    "phoneNumber": "+6281234567890"
  },
  "business": {
    "id": "biz_01J...",
    "name": "AntreIn Barbershop"
  },
  "outlet": {
    "id": "out_01J...",
    "name": "Main Outlet",
    "address": {
      "formatted": "Jl. Example No. 10, Jakarta"
    },
    "timezone": "Asia/Jakarta"
  },
  "service": {
    "id": "svc_01J...",
    "name": "Haircut",
    "durationMinutes": 45,
    "price": {
      "amount": 50000,
      "currency": "IDR"
    }
  },
  "staff": {
    "id": "stf_01J...",
    "name": "Andi",
    "avatarUrl": "https://cdn.example/staff.jpg"
  },
  "scheduledAt": "2026-07-22T10:00:00+07:00",
  "expectedEndsAt": "2026-07-22T10:45:00+07:00",
  "paymentOption": "deposit",
  "paymentSummary": {
    "totalAmount": {
      "amount": 50000,
      "currency": "IDR"
    },
    "requiredNow": {
      "amount": 10000,
      "currency": "IDR"
    },
    "paidAmount": {
      "amount": 10000,
      "currency": "IDR"
    },
    "remainingAmount": {
      "amount": 40000,
      "currency": "IDR"
    },
    "status": "paid"
  },
  "queue": null,
  "customerNotes": "Please use scissors only.",
  "cancellation": {
    "canCancel": true,
    "refundEstimate": {
      "amount": 10000,
      "currency": "IDR"
    },
    "deadlineAt": "2026-07-22T04:00:00+07:00"
  },
  "createdAt": "2026-07-21T13:30:00+07:00",
  "updatedAt": "2026-07-21T13:30:00+07:00"
}
```

Customer response excludes internal staff notes and sensitive operational fields.

---

## 60. Create Booking

```http
POST /bookings
```

Authentication:

```text
Customer role
```

Idempotency:

```text
Required
```

Request:

```json
{
  "businessId": "biz_01J...",
  "outletId": "out_01J...",
  "serviceId": "svc_01J...",
  "staffSelection": {
    "mode": "specific_staff",
    "staffId": "stf_01J..."
  },
  "scheduledAt": "2026-07-22T10:00:00+07:00",
  "paymentOption": "deposit",
  "customerNotes": "Please use scissors only."
}
```

Alternative staff selection:

```json
{
  "mode": "any_available"
}
```

Allowed payment options:

```text
pay_at_location
full_payment
deposit
```

Response `201` with online payment required:

```json
{
  "success": true,
  "data": {
    "booking": {
      "id": "bkg_01J...",
      "bookingCode": "ANT-20260722-0012",
      "status": "pending_payment",
      "scheduledAt": "2026-07-22T10:00:00+07:00",
      "service": {
        "id": "svc_01J...",
        "name": "Haircut",
        "durationMinutes": 45
      },
      "staff": {
        "id": "stf_01J...",
        "name": "Andi"
      },
      "paymentOption": "deposit",
      "paymentSummary": {
        "totalAmount": {
          "amount": 50000,
          "currency": "IDR"
        },
        "requiredNow": {
          "amount": 10000,
          "currency": "IDR"
        },
        "remainingAmount": {
          "amount": 40000,
          "currency": "IDR"
        }
      }
    },
    "payment": {
      "id": "pay_01J...",
      "status": "pending",
      "provider": "provider_name",
      "expiresAt": "2026-07-21T13:45:00+07:00",
      "checkout": {
        "type": "redirect_url",
        "url": "https://payment.example/checkout"
      }
    }
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

Response `201` for pay at location:

```json
{
  "success": true,
  "data": {
    "booking": {
      "id": "bkg_01J...",
      "bookingCode": "ANT-20260722-0012",
      "status": "confirmed",
      "scheduledAt": "2026-07-22T10:00:00+07:00",
      "paymentOption": "pay_at_location",
      "paymentSummary": {
        "totalAmount": {
          "amount": 50000,
          "currency": "IDR"
        },
        "requiredNow": {
          "amount": 0,
          "currency": "IDR"
        },
        "remainingAmount": {
          "amount": 50000,
          "currency": "IDR"
        },
        "status": "pending"
      }
    },
    "payment": null
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

Errors:

- `BOOKING_SLOT_UNAVAILABLE`
- `BOOKING_DATE_IN_PAST`
- `BOOKING_LEAD_TIME_NOT_MET`
- `BOOKING_HORIZON_EXCEEDED`
- `BOOKING_ACTIVE_LIMIT_REACHED`
- `BUSINESS_NOT_ACTIVE`
- `OUTLET_NOT_ACTIVE`
- `SERVICE_NOT_ACTIVE`
- `STAFF_NOT_ACTIVE`
- `STAFF_NOT_ELIGIBLE_FOR_SERVICE`
- `PAYMENT_OPTION_NOT_AVAILABLE`
- `PAYMENT_PROVIDER_UNAVAILABLE`
- `IDEMPOTENCY_KEY_REQUIRED`
- `IDEMPOTENCY_KEY_REUSED`

---

## 61. List Customer Bookings

```http
GET /bookings
```

Authentication:

```text
Customer
```

Query:

```text
status
dateFrom
dateTo
cursor
limit
```

Response `200` returns customer-safe booking summaries.

---

## 62. Get Customer Booking

```http
GET /bookings/{bookingId}
```

Authorization:

```text
Booking owner
```

Response `200` returns canonical customer booking resource.

Errors:

- `BOOKING_NOT_FOUND`
- `FORBIDDEN_BOOKING_RESOURCE`

---

## 63. Cancel Customer Booking

```http
POST /bookings/{bookingId}/cancel
```

Authorization:

```text
Booking owner
```

Idempotency:

```text
Required
```

Request:

```json
{
  "reasonCode": "customer_changed_plan",
  "reason": "I am no longer available."
}
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "bookingId": "bkg_01J...",
    "status": "cancelled",
    "cancelledAt": "2026-07-21T13:30:00+07:00",
    "refund": {
      "required": true,
      "id": "ref_01J...",
      "status": "refund_pending",
      "amount": {
        "amount": 10000,
        "currency": "IDR"
      }
    }
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

Errors:

- `BOOKING_CANNOT_BE_CANCELLED`
- `BOOKING_ALREADY_CANCELLED`
- `BOOKING_ALREADY_COMPLETED`
- `BOOKING_CANCELLATION_WINDOW_CLOSED`
- `REFUND_PROVIDER_UNAVAILABLE`

---

## 64. Check In Customer Booking

```http
POST /bookings/{bookingId}/check-in
```

Authorization:

```text
Booking owner or authorized staff
```

Idempotency:

```text
Required
```

Request:

```json
{
  "method": "customer_app"
}
```

Allowed methods:

```text
customer_app
staff_assisted
qr
```

`qr` may be reserved for a later phase.

Response `200`:

```json
{
  "success": true,
  "data": {
    "bookingId": "bkg_01J...",
    "bookingStatus": "waiting",
    "checkedInAt": "2026-07-22T09:50:00+07:00",
    "queue": {
      "id": "que_01J...",
      "queueNumber": 12,
      "displayNumber": "A012",
      "status": "waiting",
      "peopleAhead": 3,
      "currentServingNumber": "A009",
      "estimatedWaitMinutes": 45,
      "businessDate": "2026-07-22"
    }
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-22T09:50:00+07:00"
  }
}
```

Errors:

- `BOOKING_NOT_CONFIRMED`
- `BOOKING_CHECK_IN_TOO_EARLY`
- `BOOKING_CHECK_IN_TOO_LATE`
- `BOOKING_ALREADY_CHECKED_IN`
- `QUEUE_ENTRY_ALREADY_EXISTS`
- `OUTLET_QUEUE_CLOSED`

---

# Part IX — Business Booking APIs

## 65. List Business Bookings

```http
GET /businesses/{businessId}/bookings
```

Authorization:

```text
booking.read
```

Query:

```text
outletId
staffId
status
date
dateFrom
dateTo
type
paymentStatus
cursor
limit
```

Response `200` includes operational booking summaries.

Operational customer data should be limited to:

- Name.
- Phone number where required.
- Booking code.
- Service.
- Schedule.
- Payment state.
- Queue state.

---

## 66. Get Business Booking

```http
GET /businesses/{businessId}/bookings/{bookingId}
```

Authorization:

```text
booking.read and correct business/outlet scope
```

Response may include:

- Customer contact.
- Internal status history.
- Staff assignment.
- Payment summary.
- Queue summary.
- Customer notes.
- Internal notes.
- Audit-safe action availability.

---

## 67. Create Walk-In Booking

```http
POST /businesses/{businessId}/walk-ins
```

Authorization:

```text
booking.manage or queue.manage
```

Idempotency:

```text
Required
```

Request:

```json
{
  "outletId": "out_01J...",
  "customer": {
    "name": "Walk-In Customer",
    "phoneNumber": "+6281234567890"
  },
  "serviceId": "svc_01J...",
  "staffSelection": {
    "mode": "any_available"
  },
  "paymentOption": "pay_at_location",
  "notes": null
}
```

Response `201`:

```json
{
  "success": true,
  "data": {
    "booking": {
      "id": "bkg_01J...",
      "type": "walk_in",
      "status": "waiting"
    },
    "queue": {
      "id": "que_01J...",
      "queueNumber": 13,
      "displayNumber": "A013",
      "status": "waiting",
      "peopleAhead": 4
    }
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

---

## 68. Mark Booking as No-Show

```http
POST /businesses/{businessId}/bookings/{bookingId}/no-show
```

Authorization:

```text
booking.manage or queue.manage
```

Idempotency:

```text
Required
```

Request:

```json
{
  "reason": "Customer did not arrive within the allowed window."
}
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "bookingId": "bkg_01J...",
    "status": "no_show",
    "markedAt": "2026-07-22T10:20:00+07:00"
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-22T10:20:00+07:00"
  }
}
```

---

## 68.1. Cancel Business Booking

> Added per ADR 0040 (business-initiated cancellation is a separate endpoint from customer cancellation).

```http
POST /businesses/{businessId}/bookings/{bookingId}/cancel
```

Authorization:

```text
booking.manage
```

Idempotency:

```text
Required
```

Request:

```json
{
  "reasonCode": "business_unavailable",
  "reason": "Staff member is ill; we cannot honor the appointment."
}
```

`reasonCode` and `reason` are required.

Behavior (ADR 0040):

- Customer receives a full refund of net paid amount regardless of timing thresholds.
- Audit record is required.
- Customer notification is required.

Response `200` mirrors the customer cancellation response shape.

Errors:

- `BOOKING_NOT_FOUND`
- `BOOKING_CANNOT_BE_CANCELLED`
- `BOOKING_ALREADY_CANCELLED`
- `BOOKING_ALREADY_COMPLETED`

---

# Part X — Payment APIs

## 69. Payment Resource

```json
{
  "id": "pay_01J...",
  "bookingId": "bkg_01J...",
  "provider": "provider_name",
  "providerReference": "external_reference",
  "paymentOption": "deposit",
  "status": "paid",
  "amount": {
    "amount": 10000,
    "currency": "IDR"
  },
  "paidAt": "2026-07-21T13:35:00+07:00",
  "expiresAt": "2026-07-21T13:45:00+07:00",
  "createdAt": "2026-07-21T13:30:00+07:00",
  "updatedAt": "2026-07-21T13:35:00+07:00"
}
```

---

## 70. Get Booking Payments

```http
GET /bookings/{bookingId}/payments
```

Authorization:

```text
Booking owner or authorized business member
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "pay_01J...",
        "status": "paid",
        "paymentOption": "deposit",
        "amount": {
          "amount": 10000,
          "currency": "IDR"
        },
        "paidAt": "2026-07-21T13:35:00+07:00"
      }
    ]
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:35:00+07:00"
  }
}
```

---

## 71. Get Payment

```http
GET /payments/{paymentId}
```

Authorization:

```text
Booking owner or authorized business member
```

Response `200` returns payment resource.

---

## 72. Refresh Payment Status

```http
POST /payments/{paymentId}/refresh
```

Authorization:

```text
Booking owner or authorized business member
```

Idempotency:

```text
Recommended
```

Purpose:

- Query provider state when webhook delivery is delayed.
- Never bypass signature-verified provider evidence.
- Must be rate-limited.

`refreshedFromProvider` is `false` when the provider could not be queried (ADR
0029) — the stored state is returned and the request never fails over provider
unavailability.

Response `200`:

```json
{
  "success": true,
  "data": {
    "payment": {
      "id": "pay_01J...",
      "status": "paid",
      "paidAt": "2026-07-21T13:35:00+07:00"
    },
    "bookingStatus": "confirmed",
    "refreshedFromProvider": true
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:36:00+07:00"
  }
}
```

Errors:

- `PAYMENT_NOT_FOUND`
- `PAYMENT_STATUS_REFRESH_RATE_LIMITED`
- `PAYMENT_PROVIDER_UNAVAILABLE`

---

## 73. Confirm Pay-at-Location Payment

```http
POST /businesses/{businessId}/bookings/{bookingId}/payments/pay-at-location/confirm
```

Authorization:

```text
payment.confirm
```

Idempotency:

```text
Required
```

Request:

```json
{
  "amount": {
    "amount": 40000,
    "currency": "IDR"
  },
  "method": "cash",
  "note": "Paid at front desk."
}
```

Allowed methods:

```text
cash
qris_manual
bank_transfer_manual
card_terminal
other
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "payment": {
      "id": "pay_01J...",
      "status": "paid",
      "amount": {
        "amount": 40000,
        "currency": "IDR"
      },
      "method": "cash",
      "paidAt": "2026-07-22T10:50:00+07:00"
    },
    "bookingPaymentSummary": {
      "totalAmount": {
        "amount": 50000,
        "currency": "IDR"
      },
      "paidAmount": {
        "amount": 50000,
        "currency": "IDR"
      },
      "remainingAmount": {
        "amount": 0,
        "currency": "IDR"
      },
      "status": "paid"
    }
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-22T10:50:00+07:00"
  }
}
```

Errors:

- `PAYMENT_AMOUNT_MISMATCH`
- `PAYMENT_ALREADY_PAID`
- `PAYMENT_CURRENCY_MISMATCH`
- `FORBIDDEN_PAYMENT_CONFIRMATION`

---

## 74. Request Refund

```http
POST /businesses/{businessId}/payments/{paymentId}/refunds
```

Authorization:

```text
payment.refund
```

Idempotency:

```text
Required
```

Request:

```json
{
  "amount": {
    "amount": 10000,
    "currency": "IDR"
  },
  "reasonCode": "booking_cancelled",
  "reason": "Customer cancelled within full-refund window."
}
```

Response `202`:

```json
{
  "success": true,
  "data": {
    "refund": {
      "id": "ref_01J...",
      "paymentId": "pay_01J...",
      "status": "refund_pending",
      "amount": {
        "amount": 10000,
        "currency": "IDR"
      },
      "createdAt": "2026-07-21T13:30:00+07:00"
    }
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

Errors:

- `REFUND_AMOUNT_EXCEEDS_PAID_AMOUNT`
- `REFUND_NOT_ALLOWED`
- `REFUND_ALREADY_PENDING`
- `PAYMENT_NOT_REFUNDABLE`
- `PAYMENT_PROVIDER_UNAVAILABLE`

---

## 75. Get Refund

```http
GET /refunds/{refundId}
```

Authorization:

```text
Booking owner or authorized business member
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "id": "ref_01J...",
    "paymentId": "pay_01J...",
    "status": "refunded",
    "amount": {
      "amount": 10000,
      "currency": "IDR"
    },
    "reasonCode": "booking_cancelled",
    "processedAt": "2026-07-21T13:40:00+07:00",
    "createdAt": "2026-07-21T13:30:00+07:00"
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:40:00+07:00"
  }
}
```

---

# Part XI — Payment Webhooks

## 76. Payment Webhook Endpoint

Provider-specific endpoint:

```http
POST /webhooks/payments/{provider}
```

Example:

```text
/webhooks/payments/midtrans
/webhooks/payments/xendit
```

Authentication:

```text
Provider signature verification
```

The endpoint must not use customer access tokens.

---

## 77. Webhook Processing Rules

Processing sequence:

```text
Receive request
→ Read raw request body
→ Verify provider signature
→ Parse provider event
→ Derive provider event ID
→ Begin transaction
→ Check event idempotency
→ Store webhook event
→ Validate amount and currency
→ Apply valid payment transition
→ Apply booking transition when required
→ Insert outbox events
→ Commit
→ Return provider-compatible 2xx response
```

Webhook behavior:

- Duplicate valid event returns success.
- Invalid signature returns provider-appropriate rejection.
- Unknown resource is recorded for reconciliation.
- Invalid transition is recorded and does not corrupt state.
- Notification delivery occurs asynchronously.
- Raw payload storage must redact or protect sensitive fields.

---

## 78. Provider Webhook Response

Generic response:

```json
{
  "received": true
}
```

The exact response may follow provider requirements.

Internal API response envelopes are not required for provider webhooks.

---

## 79. Webhook Error Cases

Internal stable categories:

- `PAYMENT_WEBHOOK_SIGNATURE_INVALID`
- `PAYMENT_WEBHOOK_EVENT_DUPLICATE`
- `PAYMENT_WEBHOOK_PAYMENT_NOT_FOUND`
- `PAYMENT_WEBHOOK_AMOUNT_MISMATCH`
- `PAYMENT_WEBHOOK_CURRENCY_MISMATCH`
- `PAYMENT_WEBHOOK_TRANSITION_INVALID`
- `PAYMENT_WEBHOOK_PROCESSING_FAILED`

These codes are primarily for logs, metrics, and internal tooling.

---

# Part XII — Queue APIs

## 80. Customer Queue Resource

```json
{
  "id": "que_01J...",
  "bookingId": "bkg_01J...",
  "businessId": "biz_01J...",
  "outletId": "out_01J...",
  "businessDate": "2026-07-22",
  "queueNumber": 12,
  "displayNumber": "A012",
  "status": "waiting",
  "peopleAhead": 3,
  "currentServingNumber": "A009",
  "estimatedWaitMinutes": 45,
  "calledAt": null,
  "serviceStartedAt": null,
  "completedAt": null,
  "version": 4,
  "updatedAt": "2026-07-22T09:50:00+07:00"
}
```

---

## 81. Get Customer Queue

```http
GET /bookings/{bookingId}/queue
```

Authorization:

```text
Booking owner
```

Response `200` returns customer queue resource.

Errors:

- `QUEUE_ENTRY_NOT_FOUND`
- `FORBIDDEN_QUEUE_RESOURCE`

---

## 82. Get Outlet Queue Snapshot

```http
GET /businesses/{businessId}/outlets/{outletId}/queue
```

Authorization:

```text
queue.read
```

Query:

```text
date
status
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "businessDate": "2026-07-22",
    "outletId": "out_01J...",
    "isOpen": true,
    "currentServing": {
      "queueEntryId": "que_01J...",
      "displayNumber": "A009",
      "bookingId": "bkg_01J...",
      "customer": {
        "name": "Customer Name"
      },
      "service": {
        "name": "Haircut"
      },
      "staff": {
        "id": "stf_01J...",
        "name": "Andi"
      },
      "status": "in_service"
    },
    "waiting": [
      {
        "queueEntryId": "que_01J...",
        "displayNumber": "A010",
        "bookingId": "bkg_01J...",
        "customer": {
          "name": "Next Customer"
        },
        "service": {
          "name": "Haircut"
        },
        "staff": {
          "id": "stf_01J...",
          "name": "Andi"
        },
        "status": "waiting",
        "checkedInAt": "2026-07-22T09:45:00+07:00"
      }
    ],
    "version": 18,
    "updatedAt": "2026-07-22T09:50:00+07:00"
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-22T09:50:00+07:00"
  }
}
```

Business response may include customer names because staff requires operational identification.

Each snapshot entry also carries its per-entry `version`, so staff commands (§83–§89) can supply `expectedVersion` for optimistic concurrency (realtime-queue §20). No phone numbers appear in the staff snapshot (ADR 0041).

---

## 83. Call Queue Entry

```http
POST /businesses/{businessId}/queue/{queueEntryId}/call
```

Authorization:

```text
queue.manage
```

Idempotency:

```text
Required
```

Request:

```json
{
  "expectedVersion": 4
}
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "queueEntryId": "que_01J...",
    "status": "called",
    "calledAt": "2026-07-22T09:55:00+07:00",
    "version": 5
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-22T09:55:00+07:00"
  }
}
```

Errors:

- `QUEUE_ENTRY_NOT_WAITING`
- `QUEUE_HAS_CALLED_ENTRY`
- `QUEUE_VERSION_CONFLICT`
- `QUEUE_ENTRY_NOT_FOUND`
- `FORBIDDEN_QUEUE_RESOURCE`

---

## 84. Recall Queue Entry

```http
POST /businesses/{businessId}/queue/{queueEntryId}/recall
```

Authorization:

```text
queue.manage
```

Idempotency:

```text
Required
```

Request:

```json
{
  "expectedVersion": 5
}
```

Response `200` returns updated called state and recall timestamp/count.

---

## 85. Skip Queue Entry

```http
POST /businesses/{businessId}/queue/{queueEntryId}/skip
```

Authorization:

```text
queue.manage
```

Idempotency:

```text
Required
```

Request:

```json
{
  "expectedVersion": 5,
  "reason": "Customer is temporarily unavailable."
}
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "queueEntryId": "que_01J...",
    "status": "skipped",
    "version": 6,
    "updatedAt": "2026-07-22T09:56:00+07:00"
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-22T09:56:00+07:00"
  }
}
```

---

## 86. Return Skipped Entry to Waiting

```http
POST /businesses/{businessId}/queue/{queueEntryId}/return-to-waiting
```

Authorization:

```text
queue.manage
```

Idempotency:

```text
Required
```

Request:

```json
{
  "expectedVersion": 6
}
```

Response `200` returns updated waiting state.

---

## 87. Start Service

```http
POST /businesses/{businessId}/queue/{queueEntryId}/start-service
```

Authorization:

```text
queue.manage
```

Idempotency:

```text
Required
```

Request:

```json
{
  "expectedVersion": 5,
  "staffId": "stf_01J..."
}
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "queueEntryId": "que_01J...",
    "queueStatus": "in_service",
    "bookingStatus": "in_service",
    "serviceStartedAt": "2026-07-22T10:00:00+07:00",
    "version": 6
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-22T10:00:00+07:00"
  }
}
```

Errors:

- `QUEUE_ENTRY_NOT_CALLED`
- `STAFF_NOT_AVAILABLE`
- `STAFF_NOT_ELIGIBLE_FOR_SERVICE`
- `QUEUE_VERSION_CONFLICT`

---

## 88. Complete Service

```http
POST /businesses/{businessId}/queue/{queueEntryId}/complete
```

Authorization:

```text
queue.manage
```

Idempotency:

```text
Required
```

Request:

```json
{
  "expectedVersion": 6,
  "internalNote": "Service completed successfully."
}
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "queueEntryId": "que_01J...",
    "queueStatus": "completed",
    "bookingStatus": "completed",
    "completedAt": "2026-07-22T10:45:00+07:00",
    "version": 7,
    "paymentSummary": {
      "totalAmount": {
        "amount": 50000,
        "currency": "IDR"
      },
      "paidAmount": {
        "amount": 10000,
        "currency": "IDR"
      },
      "remainingAmount": {
        "amount": 40000,
        "currency": "IDR"
      },
      "status": "partially_paid"
    }
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-22T10:45:00+07:00"
  }
}
```

Product decision:

- Service completion may be allowed with outstanding pay-at-location balance.
- Business UI must clearly show outstanding balance.
- A future policy may require payment confirmation before completion.

---

## 89. Mark Queue Entry as No-Show

```http
POST /businesses/{businessId}/queue/{queueEntryId}/no-show
```

Authorization:

```text
queue.manage
```

Idempotency:

```text
Required
```

Request:

```json
{
  "expectedVersion": 5,
  "reason": "Customer did not respond after recall."
}
```

Response `200` returns queue and booking status `no_show`.

---

## 90. Reorder Queue

```http
POST /businesses/{businessId}/outlets/{outletId}/queue/reorder
```

Authorization:

```text
queue.reorder
```

Idempotency:

```text
Required
```

Request:

```json
{
  "businessDate": "2026-07-22",
  "expectedQueueVersion": 18,
  "orderedQueueEntryIds": [
    "que_01J_A",
    "que_01J_B",
    "que_01J_C"
  ],
  "reason": "Customer with appointment priority arrived."
}
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "businessDate": "2026-07-22",
    "queueVersion": 19,
    "updatedAt": "2026-07-22T10:00:00+07:00"
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-22T10:00:00+07:00"
  }
}
```

Errors:

- `QUEUE_VERSION_CONFLICT`
- `QUEUE_REORDER_INVALID_ENTRIES`
- `QUEUE_REORDER_REASON_REQUIRED`
- `FORBIDDEN_QUEUE_REORDER`

---

# Part XIII — Notification APIs

## 91. Notification Resource

```json
{
  "id": "ntf_01J...",
  "type": "queue_called",
  "title": "Your queue number is being called",
  "body": "Please proceed to the service area.",
  "resource": {
    "type": "booking",
    "id": "bkg_01J..."
  },
  "isRead": false,
  "createdAt": "2026-07-22T09:55:00+07:00",
  "readAt": null
}
```

---

## 92. List Notifications

```http
GET /notifications
```

Query:

```text
isRead
type
cursor
limit
```

Response `200` returns paginated notifications.

---

## 93. Get Notification

```http
GET /notifications/{notificationId}
```

Authorization:

```text
Notification owner
```

Response `200` returns notification resource.

---

## 94. Mark Notification as Read

```http
POST /notifications/{notificationId}/read
```

Naturally idempotent.

Response `200`:

```json
{
  "success": true,
  "data": {
    "id": "ntf_01J...",
    "isRead": true,
    "readAt": "2026-07-22T10:00:00+07:00"
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-22T10:00:00+07:00"
  }
}
```

---

## 95. Mark All Notifications as Read

```http
POST /notifications/read-all
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "updatedCount": 8
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-22T10:00:00+07:00"
  }
}
```

---

# Part XIV — Review APIs

## 96. Create Review

```http
POST /bookings/{bookingId}/review
```

Authorization:

```text
Booking owner
```

Idempotency:

```text
Required
```

Request:

```json
{
  "rating": 5,
  "comment": "Great service and short waiting time."
}
```

Response `201`:

```json
{
  "success": true,
  "data": {
    "id": "rev_01J...",
    "bookingId": "bkg_01J...",
    "businessId": "biz_01J...",
    "rating": 5,
    "comment": "Great service and short waiting time.",
    "status": "published",
    "createdAt": "2026-07-22T11:00:00+07:00"
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-22T11:00:00+07:00"
  }
}
```

Errors:

- `REVIEW_BOOKING_NOT_COMPLETED`
- `REVIEW_ALREADY_EXISTS`
- `REVIEW_NOT_ALLOWED`
- `REVIEW_RATING_INVALID`

---

## 97. List Business Reviews

```http
GET /businesses/{businessId}/reviews
```

Query:

```text
rating
cursor
limit
sort
```

Supported sort:

```text
newest
oldest
rating_desc
rating_asc
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "summary": {
      "average": 4.8,
      "count": 124,
      "distribution": {
        "5": 100,
        "4": 18,
        "3": 4,
        "2": 1,
        "1": 1
      }
    },
    "items": [
      {
        "id": "rev_01J...",
        "customer": {
          "displayName": "Oki"
        },
        "rating": 5,
        "comment": "Great service.",
        "createdAt": "2026-07-22T11:00:00+07:00"
      }
    ]
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-22T11:00:00+07:00",
    "pagination": {
      "nextCursor": null,
      "hasMore": false,
      "limit": 20
    }
  }
}
```

---

# Part XV — Reporting APIs

## 98. Get Business Daily Summary

```http
GET /businesses/{businessId}/reports/daily-summary
```

Authorization:

```text
reports.read
```

Query:

```text
outletId
date
```

Response `200`:

```json
{
  "success": true,
  "data": {
    "businessId": "biz_01J...",
    "outletId": "out_01J...",
    "date": "2026-07-22",
    "timezone": "Asia/Jakarta",
    "bookings": {
      "total": 20,
      "confirmed": 4,
      "waiting": 3,
      "inService": 1,
      "completed": 10,
      "cancelled": 1,
      "noShow": 1
    },
    "queue": {
      "active": 4,
      "averageWaitMinutes": 32
    },
    "payments": {
      "grossPaid": {
        "amount": 750000,
        "currency": "IDR"
      },
      "pending": {
        "amount": 150000,
        "currency": "IDR"
      },
      "refunded": {
        "amount": 50000,
        "currency": "IDR"
      }
    }
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-22T18:00:00+07:00"
  }
}
```

---

# Part XVI — Health APIs

## 99. Liveness

```http
GET /health/live
```

Authentication:

```text
Public or infrastructure-restricted
```

Response `200`:

```json
{
  "status": "ok",
  "timestamp": "2026-07-21T13:30:00+07:00"
}
```

---

## 100. Readiness

```http
GET /health/ready
```

Response `200`:

```json
{
  "status": "ready",
  "checks": {
    "database": "up",
    "redis": "up",
    "migrations": "up"
  },
  "timestamp": "2026-07-21T13:30:00+07:00"
}
```

Response `503` when a required dependency is unavailable.

---

# Part XVII — WebSocket Contract

## 101. Connection

Endpoint:

```text
/realtime
```

Transport:

```text
WebSocket with Socket.IO-compatible handshake
```

Authentication options:

Preferred:

```json
{
  "auth": {
    "accessToken": "access-token"
  }
}
```

The final implementation must not place long-lived credentials in query-string logs.

---

## 102. Connection Acknowledgement

Server event:

```text
connection.ready.v1
```

Payload:

```json
{
  "eventId": "evt_01J...",
  "type": "connection.ready.v1",
  "occurredAt": "2026-07-21T13:30:00+07:00",
  "data": {
    "userId": "usr_01J...",
    "connectionId": "socket_connection_id",
    "serverTime": "2026-07-21T13:30:00+07:00",
    "heartbeatSeconds": 25
  }
}
```

---

## 103. Subscription Model

The server automatically subscribes the connection to:

```text
user:{userId}
```

Additional subscriptions require client commands and server authorization.

Client command:

```text
subscription.join.v1
```

Payload:

```json
{
  "requestId": "ws_req_01J...",
  "channels": [
    {
      "type": "booking",
      "resourceId": "bkg_01J..."
    },
    {
      "type": "outlet_queue",
      "resourceId": "out_01J...",
      "businessDate": "2026-07-22"
    }
  ]
}
```

Server acknowledgement:

```text
subscription.joined.v1
```

Payload:

```json
{
  "requestId": "ws_req_01J...",
  "joined": [
    {
      "type": "booking",
      "resourceId": "bkg_01J..."
    }
  ],
  "rejected": []
}
```

Rejected subscription example:

```json
{
  "requestId": "ws_req_01J...",
  "joined": [],
  "rejected": [
    {
      "type": "outlet_queue",
      "resourceId": "out_01J...",
      "code": "FORBIDDEN_QUEUE_RESOURCE"
    }
  ]
}
```

---

## 104. Common Event Envelope

```json
{
  "eventId": "evt_01J...",
  "type": "booking.updated.v1",
  "occurredAt": "2026-07-21T13:30:00+07:00",
  "resource": {
    "type": "booking",
    "id": "bkg_01J..."
  },
  "version": 4,
  "data": {}
}
```

Fields:

- `eventId`: globally unique event identifier.
- `type`: versioned event type.
- `occurredAt`: server event time.
- `resource`: primary affected resource.
- `version`: monotonically increasing resource version when applicable.
- `data`: event-specific payload.

---

## 105. Booking Updated Event

Event:

```text
booking.updated.v1
```

Payload:

```json
{
  "eventId": "evt_01J...",
  "type": "booking.updated.v1",
  "occurredAt": "2026-07-21T13:35:00+07:00",
  "resource": {
    "type": "booking",
    "id": "bkg_01J..."
  },
  "version": 3,
  "data": {
    "status": "confirmed",
    "updatedAt": "2026-07-21T13:35:00+07:00"
  }
}
```

Client action:

- Update local summary when version is newer.
- Fetch `GET /bookings/{bookingId}` when full state is needed.

---

## 106. Payment Updated Event

Event:

```text
payment.updated.v1
```

Payload:

```json
{
  "eventId": "evt_01J...",
  "type": "payment.updated.v1",
  "occurredAt": "2026-07-21T13:35:00+07:00",
  "resource": {
    "type": "payment",
    "id": "pay_01J..."
  },
  "version": 2,
  "data": {
    "bookingId": "bkg_01J...",
    "status": "paid",
    "paidAt": "2026-07-21T13:35:00+07:00"
  }
}
```

---

## 107. Customer Queue Updated Event

Event:

```text
queue.entry.updated.v1
```

Payload:

```json
{
  "eventId": "evt_01J...",
  "type": "queue.entry.updated.v1",
  "occurredAt": "2026-07-22T09:55:00+07:00",
  "resource": {
    "type": "queue_entry",
    "id": "que_01J..."
  },
  "version": 5,
  "data": {
    "bookingId": "bkg_01J...",
    "status": "called",
    "displayNumber": "A012",
    "peopleAhead": 0,
    "currentServingNumber": "A012",
    "estimatedWaitMinutes": 0,
    "calledAt": "2026-07-22T09:55:00+07:00"
  }
}
```

---

## 108. Outlet Queue Snapshot Event

Event:

```text
queue.snapshot.updated.v1
```

Business staff payload:

```json
{
  "eventId": "evt_01J...",
  "type": "queue.snapshot.updated.v1",
  "occurredAt": "2026-07-22T09:55:00+07:00",
  "resource": {
    "type": "outlet_queue",
    "id": "out_01J...:2026-07-22"
  },
  "version": 19,
  "data": {
    "outletId": "out_01J...",
    "businessDate": "2026-07-22",
    "currentServing": {
      "queueEntryId": "que_01J...",
      "displayNumber": "A012"
    },
    "waitingCount": 4,
    "skippedCount": 1
  }
}
```

The client should refetch the full queue snapshot if it needs operational details.

---

## 109. Notification Created Event

Event:

```text
notification.created.v1
```

Payload:

```json
{
  "eventId": "evt_01J...",
  "type": "notification.created.v1",
  "occurredAt": "2026-07-22T09:55:00+07:00",
  "resource": {
    "type": "notification",
    "id": "ntf_01J..."
  },
  "version": 1,
  "data": {
    "notification": {
      "id": "ntf_01J...",
      "type": "queue_called",
      "title": "Your queue number is being called",
      "body": "Please proceed to the service area.",
      "resource": {
        "type": "booking",
        "id": "bkg_01J..."
      },
      "isRead": false,
      "createdAt": "2026-07-22T09:55:00+07:00"
    }
  }
}
```

---

## 110. Server Error Event

Event:

```text
server.error.v1
```

Payload:

```json
{
  "requestId": "ws_req_01J...",
  "error": {
    "code": "FORBIDDEN_QUEUE_RESOURCE",
    "message": "You do not have access to this queue."
  }
}
```

---

## 111. Heartbeat

Socket.IO transport-level heartbeat is preferred.

If an application heartbeat is added:

Client:

```text
ping.v1
```

Server:

```text
pong.v1
```

Payload:

```json
{
  "serverTime": "2026-07-21T13:30:00+07:00"
}
```

---

## 112. Reconnection Rules

After reconnecting, Flutter must:

1. Reauthenticate.
2. Rejoin authorized subscriptions.
3. Fetch authoritative current state using REST.
4. Compare resource versions.
5. Ignore stale duplicate events.

WebSocket history replay is not required for MVP.

---

## 113. Event Delivery Guarantees

MVP event delivery semantics:

```text
At least once where retry exists
```

Therefore:

- Event IDs may repeat.
- Clients should deduplicate by `eventId` when practical.
- Resource versions prevent stale updates.
- REST recovery resolves missing events.

Exactly-once delivery is not promised.

---

# Part XVIII — Error Code Catalog

## 114. Authentication Errors

```text
AUTH_INVALID_CREDENTIALS
AUTH_EMAIL_ALREADY_REGISTERED
AUTH_PHONE_ALREADY_REGISTERED
AUTH_ACCOUNT_INACTIVE
AUTH_ACCOUNT_SUSPENDED
AUTH_ACCESS_TOKEN_INVALID
AUTH_ACCESS_TOKEN_EXPIRED
AUTH_REFRESH_TOKEN_INVALID
AUTH_REFRESH_TOKEN_EXPIRED
AUTH_REFRESH_TOKEN_REUSED
AUTH_SESSION_REVOKED
AUTH_RESET_TOKEN_INVALID
AUTH_RESET_TOKEN_EXPIRED
AUTH_PASSWORD_REUSE_NOT_ALLOWED
AUTH_SESSION_EXPIRED
```

---

## 115. Validation Errors

```text
VALIDATION_FAILED
VALIDATION_INVALID_CURSOR
VALIDATION_INVALID_DATE_RANGE
VALIDATION_INVALID_ENUM
VALIDATION_REQUIRED_FIELD
VALIDATION_INVALID_EMAIL
VALIDATION_INVALID_PHONE
VALIDATION_INVALID_MONEY
VALIDATION_INVALID_TIMEZONE
```

---

## 116. Authorization Errors

```text
FORBIDDEN
FORBIDDEN_BUSINESS_RESOURCE
FORBIDDEN_BOOKING_RESOURCE
FORBIDDEN_PAYMENT_RESOURCE
FORBIDDEN_QUEUE_RESOURCE
FORBIDDEN_QUEUE_REORDER
FORBIDDEN_PAYMENT_CONFIRMATION
PERMISSION_REQUIRED
MEMBERSHIP_NOT_FOUND
MEMBERSHIP_INACTIVE
OUTLET_ASSIGNMENT_REQUIRED
```

---

## 117. Business Errors

```text
BUSINESS_NOT_FOUND
BUSINESS_NOT_ACTIVE
BUSINESS_LIMIT_REACHED
BUSINESS_NAME_ALREADY_EXISTS
BUSINESS_VERIFICATION_REQUIRED
OUTLET_NOT_FOUND
OUTLET_NOT_ACTIVE
OUTLET_NOT_IN_BUSINESS
```

---

## 118. Service and Staff Errors

```text
SERVICE_NOT_FOUND
SERVICE_NOT_ACTIVE
SERVICE_NOT_IN_BUSINESS
SERVICE_NAME_ALREADY_EXISTS
SERVICE_INVALID_DURATION
SERVICE_INVALID_PRICE
SERVICE_INVALID_DEPOSIT
STAFF_NOT_FOUND
STAFF_NOT_ACTIVE
STAFF_NOT_IN_BUSINESS
STAFF_NOT_ELIGIBLE_FOR_SERVICE
STAFF_NOT_AVAILABLE
STAFF_ALREADY_MEMBER
STAFF_INVITATION_ALREADY_PENDING
STAFF_INVITATION_NOT_FOUND
STAFF_INVITATION_EXPIRED
STAFF_HAS_ACTIVE_BOOKINGS
```

---

## 119. Schedule Errors

```text
SCHEDULE_DATE_OUT_OF_RANGE
SCHEDULE_DATE_IN_PAST
SCHEDULE_INVALID_PERIOD
SCHEDULE_OVERLAPPING_PERIODS
SCHEDULE_INVALID_TIMEZONE
SCHEDULE_CLOSED_DATE_ALREADY_EXISTS
SCHEDULE_AFFECTS_EXISTING_BOOKINGS
```

---

## 120. Booking Errors

```text
BOOKING_NOT_FOUND
BOOKING_SLOT_UNAVAILABLE
BOOKING_DATE_IN_PAST
BOOKING_LEAD_TIME_NOT_MET
BOOKING_HORIZON_EXCEEDED
BOOKING_ACTIVE_LIMIT_REACHED
BOOKING_NOT_CONFIRMED
BOOKING_ALREADY_CHECKED_IN
BOOKING_CHECK_IN_TOO_EARLY
BOOKING_CHECK_IN_TOO_LATE
BOOKING_CANNOT_BE_CANCELLED
BOOKING_ALREADY_CANCELLED
BOOKING_ALREADY_COMPLETED
BOOKING_CANCELLATION_WINDOW_CLOSED
BOOKING_INVALID_STATUS_TRANSITION
```

---

## 121. Payment and Refund Errors

```text
PAYMENT_NOT_FOUND
PAYMENT_OPTION_NOT_AVAILABLE
PAYMENT_PROVIDER_UNAVAILABLE
PAYMENT_ALREADY_PAID
PAYMENT_ALREADY_PROCESSED
PAYMENT_AMOUNT_MISMATCH
PAYMENT_CURRENCY_MISMATCH
PAYMENT_STATUS_REFRESH_RATE_LIMITED
PAYMENT_NOT_REFUNDABLE
PAYMENT_WEBHOOK_SIGNATURE_INVALID
PAYMENT_WEBHOOK_PAYMENT_NOT_FOUND
PAYMENT_WEBHOOK_AMOUNT_MISMATCH
PAYMENT_WEBHOOK_CURRENCY_MISMATCH
PAYMENT_WEBHOOK_TRANSITION_INVALID
PAYMENT_WEBHOOK_PROCESSING_FAILED
REFUND_NOT_ALLOWED
REFUND_ALREADY_PENDING
REFUND_AMOUNT_EXCEEDS_PAID_AMOUNT
REFUND_PROVIDER_UNAVAILABLE
```

---

## 122. Queue Errors

```text
QUEUE_ENTRY_NOT_FOUND
QUEUE_ENTRY_ALREADY_EXISTS
QUEUE_ENTRY_NOT_WAITING
QUEUE_ENTRY_NOT_CALLED
QUEUE_ENTRY_NOT_SKIPPED
QUEUE_ENTRY_NOT_IN_SERVICE
QUEUE_ENTRY_ALREADY_COMPLETED
QUEUE_HAS_CALLED_ENTRY
QUEUE_VERSION_CONFLICT
QUEUE_REORDER_INVALID_ENTRIES
QUEUE_REORDER_REASON_REQUIRED
OUTLET_QUEUE_CLOSED
```

`QUEUE_HAS_CALLED_ENTRY` (409) is raised when calling an entry while another is
already `called` at the outlet — one called entry per outlet+date (ADR 0041).
`QUEUE_ENTRY_NOT_SKIPPED` / `QUEUE_ENTRY_NOT_IN_SERVICE` (409) guard
return-to-waiting and complete against the wrong source state.

---

## 122.1 Notification and Device Errors

```text
NOTIFICATION_NOT_FOUND
DEVICE_NOT_FOUND
```

Both are 404s. Knowing an ID is never permission: requesting another user's
notification or device returns `*_NOT_FOUND`, not a 403.

---

## 123. Review Errors

```text
REVIEW_BOOKING_NOT_COMPLETED
REVIEW_ALREADY_EXISTS
REVIEW_NOT_ALLOWED
REVIEW_RATING_INVALID
```

---

## 124. File Errors

```text
FILE_NOT_FOUND
FILE_NOT_OWNED
FILE_ALREADY_ATTACHED
FILE_TOO_LARGE
FILE_TYPE_NOT_ALLOWED
FILE_INVALID_CONTENT
FILE_UPLOAD_FAILED
```

---

## 125. Idempotency and Rate-Limit Errors

```text
IDEMPOTENCY_KEY_REQUIRED
IDEMPOTENCY_KEY_REUSED
IDEMPOTENCY_REQUEST_IN_PROGRESS
RATE_LIMIT_EXCEEDED
```

---

## 126. System Errors

```text
SYSTEM_INTERNAL_ERROR
SYSTEM_TEMPORARILY_UNAVAILABLE
SYSTEM_DEPENDENCY_UNAVAILABLE
SYSTEM_DATABASE_CONFLICT
SYSTEM_TIMEOUT
```

---

# Part XIX — Authorization Matrix

## 127. Permission Catalog

Recommended permissions:

```text
business.read
business.manage
service.read
service.manage
staff.read
staff.manage
schedule.read
schedule.manage
booking.read
booking.manage
queue.read
queue.manage
queue.reorder
payment.read
payment.confirm
payment.refund
reports.read
review.moderate
```

---

## 128. Role Defaults

### Customer

```text
Own profile
Own bookings
Own payments
Own queue state
Own notifications
Own reviews
```

### Owner

```text
All business permissions for owned business
```

### Manager

```text
business.read
service.read
staff.read
schedule.read
booking.read
booking.manage
queue.read
queue.manage
payment.read
payment.confirm
reports.read
```

### Barber

```text
booking.read
queue.read
queue.manage
payment.read
```

### Front Desk

```text
booking.read
booking.manage
queue.read
queue.manage
payment.read
payment.confirm
```

Permission defaults are configurable and must not replace ownership checks.

---

# Part XX — Contract Compatibility

## 129. Backward-Compatible Changes

Allowed within `v1`:

- Add optional field.
- Add endpoint.
- Add optional query parameter.
- Add new error code.
- Add new event type.
- Add new optional nested object.
- Increase maximum accepted string length.
- Add a new sort option.

---

## 130. Potentially Breaking Changes

Require explicit review:

- Add enum value when client has no unknown fallback.
- Change default sort.
- Change pagination ordering.
- Change error status code.
- Change authorization scope.
- Change nullable behavior.
- Change field precision or money semantics.

---

## 131. Breaking Changes

Require `v2` or a migration plan:

- Remove field.
- Rename field.
- Change field type.
- Change required field.
- Remove enum value.
- Replace endpoint semantics.
- Change identifier format assumptions.
- Change event payload incompatibly.

---

# Part XXI — OpenAPI and Generated Client

## 132. OpenAPI Source

NestJS code generates OpenAPI.

Generated artifact:

```text
packages/api-contracts/openapi/antrein-v1.json
```

Optional YAML:

```text
packages/api-contracts/openapi/antrein-v1.yaml
```

---

## 133. Dart Client Generation

Recommended flow:

```text
Generate OpenAPI
→ Validate
→ Generate Dart client
→ Format generated code
→ Compile mobile project
→ Run contract tests
```

Generated code location:

```text
apps/mobile/lib/core/network/generated/
```

Alternative:

```text
packages/api_client/
```

The final choice should be recorded in an ADR.

---

## 134. Generated Code Rules

- Generated code is not manually edited.
- Custom interceptors live outside generated code.
- Domain mapping lives outside generated models.
- Generated API models are not used directly throughout the UI.
- Contract changes regenerate code in CI.

---

# Part XXII — Contract Testing

## 135. Backend Contract Tests

Must verify:

- Response envelopes.
- Required fields.
- Nullability.
- Enum values.
- Error codes.
- Pagination metadata.
- Authentication requirements.
- Idempotency behavior.
- WebSocket payload shape.
- Payment-webhook idempotency.

---

## 136. Flutter Contract Tests

Must verify:

- Generated client compiles.
- JSON deserialization succeeds.
- Unknown optional fields are ignored.
- Known enum values map correctly.
- Error envelope maps to application failure types.
- Date and money parsing is correct.
- WebSocket events deserialize safely.

---

## 137. Consumer-Driven Scenarios

Critical scenarios:

1. Login and refresh.
2. Business discovery.
3. Slot availability.
4. Booking conflict.
5. Payment pending to paid.
6. App resume after payment.
7. Check-in.
8. Queue call.
9. WebSocket reconnect.
10. Booking cancellation and refund.
11. Pay-at-location confirmation.
12. Service completion.
13. Review creation.

---

# Part XXIII — Security Contract Requirements

## 138. Sensitive Fields

The API never returns:

- Password hashes.
- Refresh-token hashes.
- Webhook secrets.
- Provider private keys.
- Internal encryption keys.
- Full provider credentials.
- Unredacted payment payloads.
- Other customers’ private contact information.

---

## 139. Token Handling

- Access tokens are not returned in URLs.
- Refresh tokens are not accepted through query parameters.
- WebSocket authentication avoids long-lived tokens in logged query strings.
- Logout revokes the intended session.
- Password reset revokes existing sessions according to policy.

---

## 140. Request Logging

Request bodies must be redacted for:

```text
/auth/login
/auth/register
/auth/refresh
/auth/password/reset
/webhooks/payments/*
```

Sensitive headers must be redacted:

```text
Authorization
Cookie
X-Signature
```

---

# Part XXIV — Performance Contract

## 141. Recommended Timeouts

Flutter defaults:

```text
Connect timeout: 15 seconds
Receive timeout: 30 seconds
Send timeout: 30 seconds
```

Payment and file operations may use endpoint-specific values.

The exact values may be adjusted after measurement.

---

## 142. Payload Size

Guidelines:

- List responses are paginated.
- Business images use URLs, not inline Base64.
- WebSocket events remain compact.
- Full queue details are fetched through REST.
- File upload limits are endpoint-specific.

---

## 143. Caching

Public business-detail responses may support HTTP caching later.

Authenticated booking, payment, and queue responses should default to:

```http
Cache-Control: no-store
```

The exact cache policy is an implementation concern but must not expose private data.

---

# Part XXV — Implementation Checklist

## 144. Backend Checklist

- [ ] Global API prefix is `/api/v1`.
- [ ] OpenAPI is generated.
- [ ] Success and error envelopes are consistent.
- [ ] Request IDs are returned.
- [ ] Validation errors use field details.
- [ ] Stable error codes are implemented.
- [ ] Authorization includes resource ownership.
- [ ] Critical mutations enforce idempotency.
- [ ] Booking conflict is database-safe.
- [ ] Queue number generation is database-safe.
- [ ] Webhook raw-body verification is implemented.
- [ ] Webhook processing is idempotent.
- [ ] WebSocket events are versioned.
- [ ] REST recovery endpoints exist.
- [ ] Sensitive values are redacted.
- [ ] Contract tests run in CI.

---

## 145. Flutter Checklist

- [ ] Base URL is environment-configurable.
- [ ] Access token is attached securely.
- [ ] Refresh requests are synchronized.
- [ ] Mutation retry is disabled unless safe.
- [ ] `Idempotency-Key` is generated for supported mutations.
- [ ] Stable error codes map to typed failures.
- [ ] Unknown enum fallback exists where required.
- [ ] REST state is refetched after reconnect.
- [ ] WebSocket events are deduplicated where practical.
- [ ] Resource versions prevent stale updates.
- [ ] Payment return does not imply payment success.
- [ ] Sensitive state is cleared on logout.
- [ ] Generated client is not used directly in presentation.

---

# Part XXVI — Open Contract Decisions

## 146. Decisions Required Before Implementation

> **Resolution status (2026-07-22):** every item below is resolved in `docs/adr/` —
> gateway 0016 · push 0020 · token TTLs 0011 · discovery auth 0022 · ID format 0010 ·
> Dart client committed 0031 · search filters + file limits + rate limits + idempotency
> retention 0034 · self-check-in 0014 · queue reordering 0019 · completion balance 0032 ·
> payment expiration 0033 · multiple businesses 0026 · verification/discovery 0013 ·
> any_available 0019 (out) · payment refresh 0029 · WS namespaces 0030.
> The list is retained for historical context.

- Final payment gateway.
- Final push provider.
- Exact access-token lifetime.
- Exact refresh-token lifetime.
- Whether public business discovery requires authentication.
- Final identifier format.
- Whether generated Dart client is committed.
- Exact business search filters.
- Whether customer self-check-in is included in the first demo.
- Whether queue reordering is included in MVP.
- Whether service completion requires a zero remaining balance.
- Exact payment expiration duration.
- Exact idempotency retention.
- Exact file size limits.
- Exact rate limits.
- Whether one user may own multiple businesses in MVP.
- Whether business verification blocks public discovery.
- Whether `any_available` staff is included in the first implementation.
- Whether payment refresh queries the provider synchronously.
- Whether WebSocket uses one namespace or multiple namespaces.

These decisions must be recorded in this document or an ADR before implementation depends on them.

---

# Part XXVII — Endpoint Summary

## 147. Public and Authentication

```text
POST   /auth/register
POST   /auth/login
POST   /auth/refresh
POST   /auth/logout
POST   /auth/password/forgot
POST   /auth/password/reset
GET    /health/live
GET    /health/ready
```

## 148. Current User

```text
GET    /me
PATCH  /me
PATCH  /me/notification-preferences
PUT    /me/devices/{deviceId}
DELETE /me/devices/{deviceId}
```

## 149. Files

```text
POST   /files
GET    /files/{fileId}/content
DELETE /files/{fileId}
```

## 150. Discovery

```text
GET    /businesses
GET    /businesses/{businessId}
GET    /businesses/{businessId}/services
GET    /businesses/{businessId}/staff
GET    /businesses/{businessId}/availability
GET    /businesses/{businessId}/reviews
```

## 151. Business Management

```text
POST   /businesses
GET    /businesses/{businessId}/management
PATCH  /businesses/{businessId}
PATCH  /businesses/{businessId}/outlets/{outletId}
```

## 152. Services

```text
POST   /businesses/{businessId}/services
PATCH  /businesses/{businessId}/services/{serviceId}
POST   /businesses/{businessId}/services/{serviceId}/deactivate
```

## 153. Staff

```text
POST   /businesses/{businessId}/staff/invitations
POST   /staff/invitations/{invitationId}/accept
PATCH  /businesses/{businessId}/staff/{staffId}
POST   /businesses/{businessId}/staff/{staffId}/deactivate
```

## 154. Schedules

```text
GET    /businesses/{businessId}/outlets/{outletId}/operating-hours
PUT    /businesses/{businessId}/outlets/{outletId}/operating-hours
GET    /businesses/{businessId}/outlets/{outletId}/closed-dates
POST   /businesses/{businessId}/outlets/{outletId}/closed-dates
GET    /businesses/{businessId}/staff/{staffId}/schedule
PUT    /businesses/{businessId}/staff/{staffId}/schedule
```

## 155. Customer Bookings

```text
POST   /bookings
GET    /bookings
GET    /bookings/{bookingId}
POST   /bookings/{bookingId}/cancel
POST   /bookings/{bookingId}/check-in
GET    /bookings/{bookingId}/payments
GET    /bookings/{bookingId}/queue
POST   /bookings/{bookingId}/review
```

## 156. Business Bookings

```text
GET    /businesses/{businessId}/bookings
GET    /businesses/{businessId}/bookings/{bookingId}
POST   /businesses/{businessId}/walk-ins
POST   /businesses/{businessId}/bookings/{bookingId}/no-show
POST   /businesses/{businessId}/bookings/{bookingId}/cancel
POST   /businesses/{businessId}/bookings/{bookingId}/payments/pay-at-location/confirm
```

## 157. Payments and Refunds

```text
GET    /payments/{paymentId}
POST   /payments/{paymentId}/refresh
POST   /businesses/{businessId}/payments/{paymentId}/refunds
GET    /refunds/{refundId}
POST   /webhooks/payments/{provider}
```

## 158. Queue

```text
GET    /businesses/{businessId}/outlets/{outletId}/queue
POST   /businesses/{businessId}/queue/{queueEntryId}/call
POST   /businesses/{businessId}/queue/{queueEntryId}/recall
POST   /businesses/{businessId}/queue/{queueEntryId}/skip
POST   /businesses/{businessId}/queue/{queueEntryId}/return-to-waiting
POST   /businesses/{businessId}/queue/{queueEntryId}/start-service
POST   /businesses/{businessId}/queue/{queueEntryId}/complete
POST   /businesses/{businessId}/queue/{queueEntryId}/no-show
POST   /businesses/{businessId}/outlets/{outletId}/queue/reorder
```

## 159. Notifications

```text
GET    /notifications
GET    /notifications/{notificationId}
POST   /notifications/{notificationId}/read
POST   /notifications/read-all
```

## 160. Reports

```text
GET    /businesses/{businessId}/reports/daily-summary
```

---

## 161. Final Contract Statement

The AntreIn API contract uses:

```text
Flutter
→ HTTPS REST for authoritative state and mutations
→ Secure WebSocket for real-time events
→ Stable error codes for client behavior
→ Idempotency keys for critical retries
→ OpenAPI for generated and validated contracts
```

The contract is successful when:

- Flutter never guesses critical business state.
- Backend responses remain stable and typed.
- Booking and queue conflicts produce predictable errors.
- Payment success is confirmed through trusted server-side evidence.
- WebSocket disconnects are recoverable through REST.
- Authorization protects every resource by role, membership, outlet, and ownership.
- Contract changes are reviewable, testable, and backward-compatible.

# Mock API contract

The interfaces in `src/api/types.ts` describe the behavior the app uses. `createMockApis()` supplies an in-memory implementation. There is no HTTP server, wire format, or persistent session contract.

## Authentication

The demo account is `demo@example.com`. Password sign-in requires `password123`. Email-code sign-in requires requesting a code for the demo email and then entering `123456`. No email is sent. Each request allows one attempt, including a failed attempt. Email comparison ignores surrounding whitespace and letter case. A successful sign-in sets the current session for this API instance; sign-out clears it. A page reload creates a new instance and loses the session.

The `AuthApi` methods are `getSession`, `signInWithPassword`, `requestEmailCode`, `signInWithEmailCode`, and `signOut`. Expected failures use fixed `ApiError` codes such as `INVALID_CREDENTIALS`, `EMAIL_NOT_SUPPORTED`, `CODE_NOT_REQUESTED`, and `INVALID_CODE`. Error messages contain no submitted values.

## Items

The item API starts with one **Sample item**. `list`, `create`, `update`, and `delete` require a signed-in session. New and changed titles and descriptions are trimmed. An empty title fails with `TITLE_REQUIRED`; an unknown item fails with `ITEM_NOT_FOUND`. Item values returned to callers are copies. Data lasts only as long as this API instance and resets on reload.

The mock checks the signed-in identity when reading or changing items. This is an example boundary, not real browser security. A future server must enforce authorization itself.

## Replacing the mock

Create real adapters that implement `AuthApi` and `ItemsApi` once a backend contract exists, then supply them where the app creates its services. Preserve the app-facing success and expected-failure behavior or update the app and tests together. Specify endpoints, session storage, server-side authorization, pagination, and transport errors with that backend. The mock does not choose them in advance.

Diagnostics accept only fixed outcome names. Do not log credentials, email addresses, codes, item text, request bodies, or raw error messages when adding an adapter.

# Mock API contract

This document describes the behavior exposed by the Dart APIs in `lib/core/`.
It is the contract a future adapter should preserve for the app. There is no
HTTP server, endpoint, wire format, or HTTP status-code contract today.

## Authentication

`AuthApi` exposes these asynchronous operations:

```dart
Session? get currentSession;
Future<Session> signInWithPassword({required String email, required String password});
Future<void> requestEmailOtp({required String email});
Future<Session> signInWithEmailOtp({required String email, required String code});
Future<void> signOut();
```

Both sign-in methods accept the demo identity `demo@example.com` (email
comparison trims surrounding whitespace and ignores case). Password sign-in
also requires `password123`. Email-code sign-in requires code `123456` and a
successful `requestEmailOtp` for that email on the same API instance first. No
message is sent. A request enables one code-sign-in attempt: the request is
consumed before the code is checked, so a wrong code also uses it and another
request is needed. Repeated requests for the same email still allow one
attempt. Unsupported email or password throws
`AuthFailure(AuthFailureReason.invalidCredentials)`; code sign-in without a
pending request throws `AuthFailure(AuthFailureReason.otpNotRequested)`; a
wrong code throws `AuthFailure(AuthFailureReason.invalidOtp)`.

Either successful sign-in sets and returns the same `Session` (`userId` is
`demo-user`; `email` is `demo@example.com`). `currentSession` is null before
sign-in and after `signOut`. The session exists only in this `MockAuthApi`
instance's memory. There is no refresh, expiry, or persistence behavior.

## Items

`ItemsApi` exposes:

```dart
Future<List<Item>> getAll();
Future<Item?> getById(String id);
Future<Item> create({required String title, required String description});
Future<Item?> update(Item item);
Future<bool> delete(String id);
```

Each `MockItemsApi` instance starts with `sample-1` titled `Sample item`,
unless constructed with a different `initialItems` list. Reads and writes use
that instance's in-memory map; data is not shared between instances and is not
persisted. `getAll` returns the items in insertion order as an unmodifiable
list. `getById` returns null when absent.

Create trims title and description, rejects an empty trimmed title with
`ItemFailure(ItemFailureReason.titleRequired)`, and returns the stored item
with a generated `item-N` id. Update returns null without writing when the id
does not exist; otherwise it applies the same trimming and title validation,
preserves the id, and returns the updated item. Delete returns true if it
removed an item and false if the id was absent. `Item` values are immutable.

## Adapter behavior

Keep these Dart results and failures stable even if a future implementation
uses HTTP: preserve `Session` and `Item` values, null for missing reads or
updates, the delete boolean, trimming and required-title validation, and the
typed auth/item failures. Network, decoding, and other unexpected failures
may propagate as errors; the ViewModels catch them and show their existing
generic retry messages. The authentication ViewModel maps `AuthFailure` to
user-facing sign-in errors, while the item editor handles validation and missing
records separately. `AppServices` supplies demo credentials to the sign-in view
only for its default mock auth; a supplied real adapter does not display or
prefill them. A server's endpoints, request/response bodies, status
codes, persistence, and session security must be specified independently; this
mock contract does not imply any of them.

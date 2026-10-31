# Kankal Flutter Starter

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

A solo entrepreneur who starts many Flutter apps and uses coding agents to
build them. The starter is copied into a new project's folder or monorepo.

## Product Purpose

Provide a working, understandable foundation so a new Flutter project can
start with common app flows instead of rebuilding them from scratch. Success
means the copied app runs without a backend, demonstrates its conventions, and
can be adapted to a real product without carrying demo behavior unnoticed.

## Operating Context

The main app targets iOS, Android, macOS, Windows, and Linux. Its shared UI
package has a separate showcase app. Work is run through FVM and developed
with a test-first cycle using coding agents.

## Capabilities and Constraints

- Stacked ViewModels own screen state and actions. Named routes guard the
  signed-in item flow.
- The runnable demo supports email/password and email-code sign-in and an item
  list with create, edit, and delete actions.
- Authentication and items use replaceable API contracts with in-memory mock
  implementations. Demo credentials are not real security; no backend, email
  delivery, or persistent session is configured.
- The local UI package owns presentation. App screens own navigation and
  feature behavior.
- Diagnostics record fixed event names, source categories, and severity locally
  in debug builds. Unexpected errors add only their type and stack, without
  credential or item-content payloads. No remote telemetry provider is chosen.

## Brand Commitments

Kankal is the starter's name. The design package is meant to be adapted for
each product; no fixed brand identity for copied projects has been chosen.

## Product Principles

- Keep a copied starter runnable without outside services.
- Show one complete path through each common capability.
- Keep product behavior and visual components at clear boundaries.
- Make mock behavior explicit so it cannot be mistaken for production auth.
- Test observable behavior one increment at a time.

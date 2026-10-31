# Kankal Web Starter

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack

The owner chose Vite, React, TypeScript, Bun, and shadcn/ui.

## Users

A solo entrepreneur who copies a working starter into new web products and uses coding agents to adapt it.

## Product Purpose

Provide a runnable web and Rust foundation for common SaaS flows. A new project should start with user sign-in and persistent, user-owned example data.

## Operating Context

The starter lives beside other project starters in Kankal. The owner keeps product notes, application code, tests, and eventual backend work together. The web journey connects sign-in and item management to the Rust workspace service.

## Capabilities and Constraints

- Password sign-in, protected navigation, and item create, read, update, and delete flows.
- PostgreSQL stores manually created users, sessions, and user-owned items. No registration or recovery email is provided.
- Reusable shadcn/ui-based presentation, responsive layouts, form validation, loading, empty, error, and success states.
- A keyboard skip link and a generic render-error recovery screen.
- Fixed local diagnostic events without credentials, email addresses, codes, item contents, or raw error messages.
- Test-driven implementation and a browser test for the complete journey.
- Pagination is outside this small in-memory example; a real paging contract waits for a backend that needs it.

## Brand Commitments

Kankal is the starter's name. The owner chose a neutral, polished workspace for the demo. Its appearance is a replaceable starting point for copied products.

## Product Principles

- Run locally with a dedicated PostgreSQL database.
- Make persisted and simulated behavior clear.
- Show one complete path through each common capability.
- Keep application behavior and reusable presentation at clear boundaries.
- Verify observable behavior and the real browser journey.

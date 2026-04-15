# ADR-0005: Per-module Codable blobs in Application Support, atomic writes

**Status:** Accepted · 2026-04-14

## Context
We need persistence for module state (shelf items, pinned items, last media controller used, settings). Requirements: durable across crashes, easy to inspect/reset, no schema migration treadmill in MVP.

## Decision
Each module gets a sandboxed `ModuleStore<T: Codable>` rooted at `~/Library/Application Support/Ledge/modules/<identifier>/state.json`. Writes are atomic (write-temp + `replaceItem`). Reads are lazy + cached. Settings live at `~/Library/Application Support/Ledge/settings.json`.

File-bound URLs (File Shelf items) are stored as **security-scoped bookmark data** alongside metadata, resolved on read with `bookmarkDataIsStale` handling.

## Alternatives
- `UserDefaults` for everything: opaque, hard to debug, conflates settings with content.
- Core Data / SwiftData: overkill, slows iteration, schema migration cost.
- SQLite: justified later for analytics or large clipboard history; not for MVP.

## Consequences
- Trivial to inspect (`open ~/Library/Application\ Support/Ledge`).
- Reset by deleting a folder.
- Schema evolves via additive Codable fields; breaking changes versioned per file (`schemaVersion` field).
- If/when a module outgrows JSON, it can adopt SQLite locally without affecting others.

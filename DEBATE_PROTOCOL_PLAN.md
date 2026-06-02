# Debate Protocol Evolution Plan

## Summary

The existing WelcomTalk app is a strong foundation for a larger debate protocol.
It already enforces structured, equal-time speaking, reduces interruptions, and
supports real-time sync across devices.

## What we discussed

- The current app is optimized for two-party, turn-based conversations.
- The idea can scale to politics and global debate because it introduces a
  queue-based speaking protocol.
- The core value is a neutral structure that lets everyone speak in order,
  even when discussions do not have a hard end.
- This is different from free-for-all chat or unmoderated video debates.

## Changes implemented

- Added `WelcomTalk/WelcomTalk/Models/DebateSessionProtocol.swift`.
- Updated `WelcomTalk/WelcomTalk/ViewModels/SessionViewModel.swift` to conform to
  `DebateSessionProtocol`.
- Added documentation in `README.md` describing the future global debate protocol
  direction.
- Updated `AGENTS.md` with a short note that this repo is evolving toward a
  debate protocol abstraction.

## Suggested next session work

1. Add a multi-party participant queue model:
   - `DebateParticipant`
   - speaker queue / moderation queue
   - joined participants list
2. Extend `Session` or a new `DebateSession` model for:
   - debate roles (moderator, pro, con, audience)
   - topic metadata
   - rounds and timed speeches
   - scoring / feedback
3. Add global room sync support:
   - WebSocket room IDs
   - participant presence state
   - reconnect/resume behavior
4. Update UI copy and screens:
   - rename `WelcomTalk` to debate protocol branding if desired
   - add debate room creation / join flow
   - show queue/order and active speaker metadata

## Why this is useful

This document captures our design intent so the next session can continue with a
clear implementation roadmap, rather than repeating the discussion.

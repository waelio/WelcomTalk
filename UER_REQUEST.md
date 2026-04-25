# User Request and Resolution Workflow

This document defines the current product direction for the WelcomTalk request flow.

The goal is to support **peaceful resolution first**, while still keeping a structured record that can be exported later if a formal or legal process becomes necessary.

## Simple Product Vision

WelcomTalk is a guided conversation app for individuals, groups, and moderated discussions.

- People can take turns speaking, like a panel or studio discussion.
- Everyone should have a fair chance to present their case.
- When a session uses turn-taking, speaking time should be balanced by default.
- Each person can join from their own device.
- The number of participants can vary depending on the use case.
- The app helps the group stay organized with topics, notes, documents, and session summaries.
- The main purpose is peaceful resolution, clear communication, and useful follow-up.

## Core Fairness Principle

The same core idea should apply across the app:

- every participant deserves an equal chance to be heard
- the app should help prevent one person from dominating the conversation
- the app should stay neutral and give structure, not decide who is right
- people may disagree or fight, but the app gives everyone a fair opportunity to speak and respond

## Simple Marketing Note

WelcomTalk can be marketed to **two main audiences**.

### Individuals

- one-to-one conversations
- family discussions
- small group conversations
- conflict resolution
- private planning or follow-up sessions

### Studios and Professional Teams

- multi-person discussions
- panel-style discussions
- moderated conversations
- remote interviews or talk sessions
- structured turn-taking between participants

## Commercial Direction

WelcomTalk can become a paid product later.

- Start with a strong guided discussion experience.
- Later add paid features such as saved history, exports, moderation tools, branding, and team access.

## Product Direction

WelcomTalk should primarily help people:

- explain their issue clearly
- present their side fairly
- share supporting documents
- create a structured case record
- move toward review, discussion, and resolution

The product should **not** be framed as a court-first tool at this stage.

However, the system should preserve enough structure that records can be exported later if needed for formal follow-up.

## Primary Goal

Create a website-based request form in the related site project:

- Website/design reference: `https://github.com/waelio/welcom-port.git`
- The form should collect the user's request details
- The submission should produce a JSON configuration / case record
- The JSON record can later be consumed by the app or a backend workflow

## Core Principles

1. **Resolution-first UX**
   - The experience should encourage clarity, documentation, and constructive follow-up.

2. **Equal participation and fairness**
   - Every participant should have a fair chance to speak and respond.
   - Turn-based sessions should support balanced speaking time by default.

3. **Structured record keeping**
   - Every request should become a clean, traceable record.

4. **Role-based workflow**
   - Do not hardcode specific people or names into the product flow.
   - Use generic roles instead.

5. **Future legal compatibility**
   - If formal/legal use is needed later, records should be exportable.
   - Do not claim court-grade evidence handling unless legal requirements are explicitly defined and implemented.

## Website Request Form

The public website should include a request form with the following fields:

1. **Full Name**
   - text input

2. **Topic**
   - short text input

3. **Request Summary**
   - multi-line text area
   - explains the issue or desired outcome

4. **Supporting Documents**
   - file upload
   - examples: contracts, screenshots, letters, IDs, supporting PDFs

5. **Additional Notes**
   - optional text area

6. **Consent / Confirmation**
   - checkbox confirming that the user agrees to submit the information for review and storage

7. **Submit Request**
   - submit button

## Output Requirement

Submitting the form should create a structured JSON record.

Minimum JSON fields should include:

- `requestId`
- `createdAt`
- `fullName`
- `topic`
- `summary`
- `additionalNotes`
- `status`
- `attachments`
- `source`

## Suggested JSON Shape

```json
{
  "requestId": "generated-id",
  "createdAt": "ISO-8601 timestamp",
  "source": "website",
  "fullName": "User name",
  "topic": "Request topic",
  "summary": "Short problem description",
  "additionalNotes": "Optional notes",
  "status": "submitted",
  "attachments": [
    {
      "fileName": "document.pdf",
      "contentType": "application/pdf",
      "storageRef": "uploaded-file-reference"
    }
  ]
}
```

## Workflow Roles

The workflow should remain role-based and flexible.

Suggested roles:

- **Requester** — the person submitting the issue
- **Reviewer** — internal person who reviews the request
- **Document Preparer** — person who prepares required supporting documents if needed
- **Responder / Approver** — the person or party who responds, agrees, rejects, or requests changes

## Suggested Request Statuses

Use clear statuses instead of people-specific steps:

- `draft`
- `submitted`
- `under_review`
- `documents_requested`
- `documents_prepared`
- `awaiting_response`
- `meeting_scheduled`
- `resolved`
- `escalated`
- `closed`

## Implementation Phases

### Phase 1: Frontend Prototype

- build the form on the website
- validate required fields
- generate the JSON record
- allow local preview or download of the generated JSON

### Phase 2: Submission Workflow

- send the JSON to a backend service
- upload supporting documents to storage
- store file references in the JSON record
- assign request status and tracking

### Phase 3: Formal Record Export

- export a complete request package
- include timestamps, attachments, and status history
- support internal review or formal/legal follow-up if needed

## Important Product Boundaries

At this stage, WelcomTalk should **not** assume:

- that every request goes to court
- that the current workflow is legally final
- that one specific person always reviews first
- that uploaded records are automatically court-admissible evidence

If court-use becomes a formal requirement later, legal guidance will be needed for:

- audit trail design
- timestamps and change history
- retention policy
- data integrity
- privacy compliance
- export requirements

## Open Questions

These points still need clarification before a full production workflow is implemented:

- What participant counts should the MVP support?
- Who reviews the request first?
- Are supporting documents required at submission time?
- Should the website store files directly, or only generate JSON first?
- Which backend or storage system should receive submissions?
- What information is required for formal/legal export?
- Should the iOS app read or manage these request records?

## Current Decision

The current preferred direction is:

- **peaceful resolution first**
- **structured documentation second**
- **formal/legal export as a future capability, not the primary user experience**

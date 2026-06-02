# PRD: Peppy MVP - Personalized Peptide Protocol Engine

**Status**: needs-triage  
**Created**: 2026-05-03

---

## Problem Statement

People taking peptides - especially newer compounds like Retatrutide with limited research - lack accessible tools to understand what's happening in their bodies. They face:

- **No systematic tracking**: Scattered notes, forgotten doses, no clear picture of their response over time
- **Generic guidance**: Static dosing charts that don't account for individual variation
- **Delayed recognition of issues**: Side effects or anomalies go unnoticed until they become serious
- **Information overload**: Research is fragmented across forums, studies, and anecdotal reports

Existing solutions either require expensive medical oversight or provide only basic tracking without intelligence.

## Solution

Peppy is a mobile-first personalized peptide protocol engine that:

1. **Tracks protocols systematically** - Users log their compounds, doses, timing, and responses in one place
2. **Aggregates health data** - Pulls from wearables (Apple Health, Oura, Whoop) and manual lab entries to build a complete picture
3. **Learns individual patterns** - AI/ML engine identifies how each user responds to their protocol
4. **Provides adaptive guidance** - Flags anomalies, suggests adjustments, and helps users optimize their protocols
5. **Respects privacy** - HIPAA-compliant storage ensures sensitive health data stays secure

## User Stories

1. As a new peptide user, I want to set up my first protocol with guided steps, so that I don't miss important details
2. As a user starting titration, I want to log my starting dose and schedule, so that I can track my progression
3. As a user on-protocol, I want to receive dose reminders, so that I maintain consistency
4. As a user experiencing side effects, I want to log symptoms quickly, so that I can correlate them with my protocol
5. As a user, I want to see my weight trend over time, so that I can measure protocol effectiveness
6. As a user, I want to connect my Apple Health data, so that my sleep and activity sync automatically
7. As a user, I want to connect my Oura ring, so that my HRV and readiness scores sync automatically
8. As a user, I want to connect my Whoop band, so that my strain and recovery data sync automatically
9. As a user, I want to manually enter blood work results, so that I can track metabolic markers
10. As a user, I want to see all my data on a unified dashboard, so that I get a complete picture
11. As a user, I want to see trends over configurable time ranges (week, month, 3 months), so that I can spot patterns
12. As a user, I want to be alerted when a metric deviates from my baseline, so that I catch issues early
13. As a user, I want AI-generated insights about my data, so that I understand what's happening
14. As a user, I want dosing adjustment suggestions based on my response, so that I can optimize my protocol
15. As a user, I want to see why a suggestion was made, so that I can trust the recommendation
16. As a user, I want to dismiss or accept suggestions, so that I stay in control
17. As a user, I want to track multiple compounds simultaneously, so that I can manage stacks
18. As a user, I want to see my protocol history, so that I can review past cycles
19. As a user, I want to export my data, so that I can share it with a healthcare provider
20. As a user, I want my data encrypted and stored securely, so that my health information stays private
21. As a user, I want to use biometric login (Face ID/Touch ID), so that access is quick but secure
22. As a user, I want to set check-in reminders, so that I log data consistently
23. As a user, I want a quick daily check-in flow, so that logging doesn't feel burdensome
24. As a user, I want to add notes to any entry, so that I capture context
25. As a user, I want to search my history, so that I can find specific entries
26. As a user on the web, I want to see a compelling landing page, so that I understand the product value
27. As a potential user, I want to see how Peppy works before downloading, so that I can evaluate fit
28. As a potential user, I want clear app store links, so that I can download easily

## Implementation Decisions

### Architecture

- **Mobile App**: Native iOS (Swift) and Android (Kotlin), or cross-platform (React Native/Flutter) - decision pending based on timeline and team resources
- **Backend**: Cloud-hosted microservices with HIPAA-compliant infrastructure (AWS/GCP with BAA)
- **Database**: Encrypted at rest and in transit, with audit logging for PHI access
- **API**: RESTful or GraphQL API with JWT authentication
- **ML Pipeline**: Separate service for adaptive engine, processing user data to generate insights

### Module Interfaces

- **Auth Module**: OAuth 2.0 + biometric, refresh token rotation, session management
- **Protocol Manager**: CRUD operations with versioning (track protocol changes over time)
- **Check-in Module**: Flexible schema to accommodate different check-in types (quick, detailed, symptom-specific)
- **Wearable Sync**: Adapter pattern for each integration (Apple Health, Oura, Whoop) with normalized data model
- **Insights Engine**: Async processing, returns insights with confidence scores and explanations
- **Notification Service**: FCM (Android) + APNs (iOS), user preference controls

### Data Model (High-Level)

- **User**: Account info, preferences, auth credentials (hashed)
- **Protocol**: Compounds, doses, frequency, start/end dates, notes
- **CheckIn**: Timestamp, type, data payload (symptoms, weight, notes)
- **LabResult**: Timestamp, panel type, individual markers with values
- **WearableData**: Normalized metrics (sleep, HRV, steps, etc.) with source tracking
- **Insight**: Generated observation, confidence, supporting data references, user action (accepted/dismissed)

### Security & Compliance

- HIPAA-compliant hosting (AWS with BAA or GCP with BAA)
- Encryption at rest (AES-256) and in transit (TLS 1.3)
- PHI access audit logging
- Data retention and deletion policies
- No PHI in logs or error tracking

## Testing Decisions

### Testing Philosophy

- Test external behavior, not implementation details
- Tests should be resilient to refactoring
- Focus on user-facing outcomes and data integrity

### Modules with Comprehensive Tests

| Module | Test Focus |
|--------|------------|
| **Auth** | Registration flow, login/logout, token refresh, biometric unlock, session expiry, invalid credentials |
| **Protocol Manager** | CRUD operations, validation rules, versioning, concurrent edits |
| **Check-in** | Data entry, validation, retrieval, date range queries |
| **Lab Entry** | Data entry, validation, marker parsing, historical queries |
| **Data Service** | Encryption verification, access control, audit logging, data export |
| **Insights Engine** | Anomaly detection accuracy, suggestion generation, explanation quality |
| **Wearable Sync** | API integration (mocked), data normalization, sync state management |

### Test Types

- **Unit tests**: Core business logic, data transformations
- **Integration tests**: API endpoints, database operations, service interactions
- **E2E tests**: Critical user flows (onboarding, check-in, viewing insights)

## Out of Scope

- Photo/measurement tracking (future feature)
- Advanced stacking optimization algorithms (future feature)
- Prescription management or telemedicine integration
- Social/community features
- Web app as a product (web is marketing only)
- Provider/clinic portal
- Apple Watch / wearable companion app

## Further Notes

- **MVP timeline**: To be determined based on team size and tech stack decision
- **Launch strategy**: iOS first (Swift), Android fast-follow, or simultaneous with cross-platform
- **Regulatory**: Not positioning as a medical device; clear disclaimers that Peppy provides information, not medical advice
- **Monetization**: TBD - likely freemium (basic tracking free, adaptive insights premium)
- **YC RFS alignment**: Fits "AI Personalized Medicine" request for startups (Summer 2026)

# ADR-0001: Mobile Tech Stack

**Status**: Pending  
**Date**: 2026-05-03

## Context

Peppy needs a mobile app for iOS and Android. We need to decide between:

1. **Native**: Swift (iOS) + Kotlin (Android)
2. **Cross-platform**: React Native or Flutter

## Options

### Option A: Native (Swift + Kotlin)

**Pros**:
- Best performance and UX
- Full access to platform APIs (HealthKit, biometrics)
- App Store approval tends to be smoother
- Better for health/fitness apps that need deep OS integration

**Cons**:
- Two codebases to maintain
- Requires expertise in both platforms
- Slower time to market

### Option B: React Native

**Pros**:
- Single codebase (JavaScript/TypeScript)
- Large ecosystem and community
- Good for teams with web experience
- Faster iteration

**Cons**:
- HealthKit/wearable integration requires native bridges
- Performance overhead for data-heavy views
- Dependency on third-party native modules

### Option C: Flutter

**Pros**:
- Single codebase (Dart)
- Excellent performance (compiles to native)
- Beautiful UI out of the box
- Good HealthKit support via plugins

**Cons**:
- Smaller ecosystem than React Native
- Dart is less common (hiring consideration)
- Some native bridges still needed for Oura/Whoop

## Decision

**Decided: 2026-05-03**

### Mobile App
**Native development**: Swift (iOS) + Kotlin (Android)

Rationale:
- Best performance for health/fitness data visualization
- Deep integration with HealthKit (iOS) and Health Connect (Android)
- Smoother App Store approval process for health apps
- Full control over biometric auth and secure storage
- Best UX for a premium health product

### Web App (Marketing Site)
**React/Next.js**

Rationale:
- SSR for SEO (important for landing pages)
- Fast iteration on marketing content
- Easy deployment (Vercel/Netlify)
- React ecosystem for UI components

## Consequences

- Two mobile codebases require platform-specific expertise
- Shared backend API serves all clients (iOS, Android, Web)
- Business logic should live in the backend to avoid duplication
- Consider shared design system tokens for consistency across platforms

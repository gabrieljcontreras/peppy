# Peppy - Domain Context

Peppy is a mobile-first personalized peptide protocol engine. It helps users track their peptide usage, understand their body's response, and receive adaptive recommendations based on their data.

## Problem Statement

People taking peptides - especially newer compounds like Retatrutide with limited research - lack accessible tools to:
- Track their protocols and responses systematically
- Understand what's happening in their bodies
- Know when to adjust dosing based on their individual response
- Identify warning signs early

Existing solutions are either too generic (static dosing charts) or require expensive medical oversight that isn't accessible to most users.

## Glossary

### Peptide Types

| Term | Definition |
|------|------------|
| **GLP-1 agonist** | Peptides that mimic glucagon-like peptide-1. Used for weight loss and blood sugar control. Examples: semaglutide (Ozempic/Wegovy), tirzepatide (Mounjaro/Zepbound). |
| **Multi-agonist** | Peptides targeting multiple receptors (GLP-1, GIP, glucagon). Example: Retatrutide (triple agonist). |
| **Research peptide** | Peptides not yet FDA-approved, often obtained through gray-market sources. Less established safety/efficacy data. |
| **Compound** | General term for a specific peptide molecule. |

### Protocol Terminology

| Term | Definition |
|------|------------|
| **Protocol** | A user's complete peptide regimen - compounds, doses, frequency, timing. |
| **Titration** | Gradually increasing dose over time to minimize side effects and find effective dose. |
| **Maintenance dose** | The stable dose a user settles on after titration. |
| **Stacking** | Using multiple peptides simultaneously for combined effects. |
| **Cycle** | A defined period of peptide use, often followed by a break. |
| **Half-life** | Time for half the peptide to clear the body. Affects dosing frequency. |

### User States

| Term | Definition |
|------|------------|
| **Naive user** | Someone who has never used peptides before. Requires careful titration. |
| **Experienced user** | Someone with prior peptide experience. May titrate faster. |
| **On-protocol** | Currently following an active peptide regimen. |
| **Off-cycle** | Taking a break from peptides. |

### Data Concepts

| Term | Definition |
|------|------------|
| **Check-in** | A user-submitted data point (symptoms, weight, measurements, notes). |
| **Lab panel** | Blood work results (metabolic panel, hormones, etc.) entered by user. |
| **Wearable sync** | Automated data import from Apple Health, Oura, or Whoop. |
| **Anomaly** | A data point that deviates significantly from the user's baseline or expected range. |
| **Insight** | An AI-generated observation or recommendation based on user data. |

### Adaptive Engine Concepts

| Term | Definition |
|------|------------|
| **Baseline** | The user's metrics before starting or changing a protocol. |
| **Response curve** | How the user's body responds to a compound over time. |
| **Adjustment suggestion** | An AI-recommended change to protocol based on data (dose, timing, etc.). |
| **Flag** | An alert when data suggests something needs attention (side effect, anomaly, plateau). |

## User Types

### Primary: Research Peptide Users
- Using newer compounds (Retatrutide, etc.) with limited guidance
- Often self-sourcing from research chemical suppliers
- Highly motivated to track and optimize
- Need more support due to less established protocols

### Secondary: Prescription GLP-1 Users
- On FDA-approved medications (Ozempic, Mounjaro, Zepbound)
- Have some medical oversight but want better tracking
- Looking for community knowledge and optimization tips

## Technical Architecture (High-Level)

### Platforms
- **Mobile App**: iOS (Swift) + Android (Kotlin or cross-platform)
- **Web App**: Marketing/landing page only (not the product)

### Backend Requirements
- HIPAA-compliant data storage
- AI/ML pipeline for adaptive engine
- API integrations: Apple Health, Oura, Whoop

### Data Sensitivity
All user health data is considered PHI (Protected Health Information). Storage, transmission, and access must comply with HIPAA requirements.

## Out of Scope (for now)

- Photo/measurement tracking
- Advanced stacking optimization
- Prescription management
- Telemedicine integration
- Social/community features

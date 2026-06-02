# ADR-0002: Backend Tech Stack

**Status**: Decided  
**Date**: 2026-05-03

## Context

Peppy requires a backend that:
- Serves iOS, Android, and web clients via API
- Stores PHI (Protected Health Information) with HIPAA compliance
- Runs an ML/AI pipeline for the adaptive insights engine
- Integrates with third-party APIs (Oura, Whoop)

## Decision

**Python + FastAPI** on HIPAA-compliant cloud infrastructure.

### Core Stack

| Component | Technology |
|-----------|------------|
| **Framework** | FastAPI |
| **Language** | Python 3.11+ |
| **Database** | PostgreSQL (encrypted) |
| **ORM** | SQLAlchemy 2.0 + Alembic migrations |
| **Auth** | JWT (access + refresh tokens) |
| **Task Queue** | Celery + Redis (for async ML jobs) |
| **ML/AI** | Python native (scikit-learn, PyTorch, or similar) |

### Infrastructure

| Component | Technology |
|-----------|------------|
| **Cloud** | AWS with BAA (or GCP) |
| **Compute** | ECS/Fargate or Lambda |
| **Database** | RDS PostgreSQL (encrypted at rest) |
| **Secrets** | AWS Secrets Manager |
| **Storage** | S3 (encrypted, for lab uploads if needed) |
| **Monitoring** | CloudWatch + Sentry (no PHI in logs) |

## Rationale

1. **ML/AI alignment**: Python is the standard for ML. Keeping backend and ML pipeline in the same language simplifies the adaptive engine integration.

2. **FastAPI benefits**:
   - Automatic OpenAPI docs (great for mobile team)
   - Async support for wearable API calls
   - Pydantic for request/response validation
   - Type hints throughout

3. **HIPAA compliance**: AWS with BAA provides the compliance foundation. Application-level controls (encryption, audit logs, access control) built on top.

4. **Developer experience**: Clean, modern Python with type safety. Easy to test and maintain.

## Consequences

- Backend team needs Python expertise
- Separate languages for backend (Python) and web frontend (TypeScript)
- API contract (OpenAPI spec) becomes the interface between teams
- ML pipeline runs in the same environment, simplifying deployment

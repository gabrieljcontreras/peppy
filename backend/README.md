# Peppy Backend

FastAPI backend for the Peppy personalized peptide protocol engine.

## Setup

### Requirements

- **Python 3.11 or 3.12** (3.13+ not supported yet — pydantic-core binaries)
- PostgreSQL 15+ (production only — dev uses SQLite)
- Redis 7+ (production only — for Celery async jobs)

### Installation

**Windows (PowerShell):**

```powershell
cd backend

# Create virtual environment with Python 3.11
py -3.11 -m venv venv         # Windows with py launcher
venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Copy environment file
copy .env.example .env
```

**macOS / Linux (zsh/bash):**

```bash
cd backend

# Create virtual environment with Python 3.11
python3.11 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Copy environment file
cp .env.example .env
```

> **Note:** `.env` is not tracked in git, so it does not transfer between machines.
> If you switch machines and there is no `.env.example` to copy, create `.env` manually
> with at least the following for local dev (SQLite — no Postgres/Redis required):
>
> ```dotenv
> DEBUG=true
> DATABASE_URL=sqlite+aiosqlite:///./peppy.db
> SECRET_KEY=<any-random-string>
> ENCRYPTION_KEY=<fernet-key>   # python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
> CORS_ORIGINS=http://localhost:3000,http://127.0.0.1:3000
> ```
>
> Then create the SQLite tables with `alembic upgrade head`.

Optional: set `ANTHROPIC_API_KEY` to enable AI-written insight narratives; without it the app uses templated text.

### Running the Server (Development)

Development mode uses SQLite — no database setup needed.

**Windows (PowerShell):**

```powershell
$env:DEBUG="true"
python -m uvicorn app.main:app --reload --port 8001
```

**macOS / Linux (zsh/bash):**

```bash
# DEBUG is read from .env; export it inline only if not set there
export DEBUG=true
python -m uvicorn app.main:app --reload --port 8001
```

### Running the Server (Production)

```bash
# Run migrations (after setting up PostgreSQL)
alembic upgrade head

# Server
uvicorn app.main:app --host 0.0.0.0 --port 8001
```

### Running Tests

```bash
pytest

# With coverage
pytest --cov=app --cov-report=html

# Specific test file
pytest tests/test_auth.py -v
```

## API Documentation

When running, API docs are available at:

- Swagger UI: http://localhost:8001/docs
- ReDoc: http://localhost:8001/redoc

## Project Structure

```
backend/
├── app/
│   ├── api/
│   │   ├── routes/      # API endpoints
│   │   └── deps.py      # Dependencies (auth, db)
│   ├── models/          # SQLAlchemy models
│   ├── services/        # Business logic
│   ├── integrations/    # External API clients
│   ├── ml/              # ML/insights engine
│   ├── config.py        # Settings
│   ├── database.py      # DB connection
│   └── main.py          # FastAPI app
├── alembic/             # Database migrations
├── tests/               # Test suite
└── requirements.txt
```


# Peppy Backend

FastAPI backend for the Peppy personalized peptide protocol engine.

## Setup

### Requirements

- Python 3.11+
- PostgreSQL 15+
- Redis 7+

### Installation

```bash
cd backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Copy environment file
cp .env.example .env
# Edit .env with your database credentials
```

### Database Setup

```bash
# Run migrations
alembic upgrade head
```

### Running the Server

```bash
# Development
uvicorn app.main:app --reload --port 8000

# Production
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### Running Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=app --cov-report=html

# Run specific test file
pytest tests/test_auth.py -v
```

## API Documentation

When running in debug mode, API docs are available at:

- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

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



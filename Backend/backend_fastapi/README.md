# TFC Transportes - Backend (FastAPI)

Proyecto backend basado en FastAPI con arquitectura modular, JWT Auth, SQLAlchemy y Alembic.

## Requisitos

- Python 3.11+
- (Opcional) PostgreSQL 14+ para entornos reales; por defecto usa SQLite en local

## Configuración rápida (dev)

```bash
python -m venv .venv
. .venv/Scripts/Activate.ps1  # Windows PowerShell
pip install -U pip
pip install -r requirements.txt

# Variables de entorno (crear .env y ajustar si es necesario)
copy .env.example .env

# Ejecutar
uvicorn app.main:app --reload

# Healthcheck
curl http://127.0.0.1:8000/health
```

## Estructura

```
backend_fastapi/
  app/
    main.py
    api/
      v1/
        __init__.py
        auth.py
        health.py
    core/
      config.py
      security.py
      deps.py
    db/
      base.py
      session.py
    models/
      __init__.py
      user.py
    schemas/
      __init__.py
      token.py
      user.py
    services/
      __init__.py
    tasks/
      __init__.py
  requirements.txt
  .env.example
  README.md
```

## Credenciales por defecto (dev)

- email: `admin@tfc.local`
- password: `admin123`

Estas se crean automáticamente al iniciar si no existe ningún usuario.




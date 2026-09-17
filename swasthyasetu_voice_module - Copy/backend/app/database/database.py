from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import declarative_base, sessionmaker
from app.config import settings

if settings.DATABASE_URL.startswith('sqlite'):
    connect_args = {'check_same_thread': False}
    engine_kwargs = {'connect_args': connect_args, 'future': True}
else:
    connect_args = {
        'connect_timeout': 10,
        'keepalives': 1,
        'keepalives_idle': 30,
        'keepalives_interval': 10,
        'keepalives_count': 5,
    }
    engine_kwargs = {
        'connect_args': connect_args,
        'future': True,
        'pool_pre_ping': True,
        'pool_recycle': 300,
        'pool_size': 10,
        'max_overflow': 20,
    }

engine = create_engine(settings.DATABASE_URL, **engine_kwargs)
SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False, expire_on_commit=False)
Base = declarative_base()

def init_db():
    from app.models import models  # noqa: F401
    Base.metadata.create_all(bind=engine)
    # Lightweight compatibility migration for the SQLite prototype DB. This
    # preserves existing rows while adding columns introduced by newer code.
    if settings.DATABASE_URL.startswith('sqlite'):
        insp = inspect(engine)
        with engine.begin() as conn:
            for table in Base.metadata.sorted_tables:
                if table.name not in insp.get_table_names():
                    continue
                existing = {c['name'] for c in inspect(engine).get_columns(table.name)}
                for col in table.columns:
                    if col.name in existing or col.primary_key:
                        continue
                    ddl_type = col.type.compile(dialect=engine.dialect)
                    default = ''
                    if col.default is not None and getattr(col.default, 'is_scalar', False):
                        value = col.default.arg
                        if isinstance(value, str): default = " DEFAULT '" + value.replace("'", "''") + "'"
                        elif isinstance(value, bool): default = ' DEFAULT ' + ('1' if value else '0')
                        elif isinstance(value, (int, float)): default = f' DEFAULT {value}'
                    nullable = '' if col.nullable else ' NOT NULL'
                    # SQLite cannot add a NOT NULL column without a default to
                    # a populated table, so use a safe empty/default value.
                    if nullable and not default:
                        if 'CHAR' in ddl_type.upper() or 'TEXT' in ddl_type.upper(): default = " DEFAULT ''"
                        elif 'BOOL' in ddl_type.upper() or 'INT' in ddl_type.upper(): default = ' DEFAULT 0'
                        else: nullable = ''
                    conn.execute(text(f'ALTER TABLE "{table.name}" ADD COLUMN "{col.name}" {ddl_type}{nullable}{default}'))

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

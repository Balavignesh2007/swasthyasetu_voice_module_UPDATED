import os
import sys
from pathlib import Path

# Ensure tests run against local SQLite database
os.environ["DATABASE_URL"] = "sqlite:///./swasthyasetu.db"

sys.path.insert(0, str(Path(__file__).resolve().parent))


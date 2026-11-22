import os
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL

# Locate the project root and load its .env file
PROJECT_ROOT = Path(__file__).resolve().parent.parent
ENV_PATH = PROJECT_ROOT / ".env"

load_dotenv(ENV_PATH, override=True)

# Read database configuration
DB_HOST = os.getenv("DB_HOST")
DB_PORT = int(os.getenv("DB_PORT", 3306))
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")

# Validate configuration
if not all([DB_HOST, DB_NAME, DB_USER, DB_PASSWORD]):
    raise ValueError("Missing database configuration in .env")

print("Connecting to:", DB_HOST)
print("Database:", DB_NAME)
print("Username:", DB_USER)

# Create connection URL
connection_url = URL.create(
    drivername="mysql+pymysql",
    username=DB_USER,
    password=DB_PASSWORD,
    host=DB_HOST,
    port=DB_PORT,
    database=DB_NAME
)

engine = create_engine(
    connection_url,
    pool_pre_ping=True,
    connect_args={"connect_timeout": 10}
)

try:
    with engine.connect() as connection:

        result = connection.execute(
            text("SELECT DATABASE(), VERSION()")
        )

        database, version = result.fetchone()

        print("\nSuccessfully connected to Amazon RDS!")
        print("Database:", database)
        print("MySQL Version:", version)

except Exception as error:
    print("\nDatabase connection failed!")
    print("Error:", error)

finally:
    engine.dispose()
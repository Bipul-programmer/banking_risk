import os
import time
from pathlib import Path

from dotenv import load_dotenv
import pandas as pd
from sqlalchemy import create_engine, text

# 1. Dynamically locate project root and load .env
PROJECT_ROOT = (
    Path(__file__).resolve().parent.parent
    if Path(__file__).resolve().parent.name == "python"
    else Path(__file__).resolve().parent
)
ENV_PATH = PROJECT_ROOT / ".env"
load_dotenv(ENV_PATH, override=True)

# 2. Read and validate database configuration
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST")
DB_PORT = int(os.getenv("DB_PORT", 3306))
DB_NAME = os.getenv("DB_NAME")

if not all([DB_USER, DB_PASSWORD, DB_HOST, DB_NAME]):
    raise ValueError(f"Missing database credentials in {ENV_PATH}")

connection_url = (
    f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
)

engine = create_engine(
    connection_url,
    pool_pre_ping=True,
    connect_args={
        "local_infile": True,
        "connect_timeout": 30
    }
)

# 3. Locate dataset
file_path = PROJECT_ROOT / "datasets/raw/home-credit-default-risk/application_train.csv"
if not file_path.exists():
    raise FileNotFoundError(f"Dataset not found at: {file_path}")

print("=" * 60)
print("BANKING & FINANCIAL RISK ANALYTICS - RDS INGESTION")
print("=" * 60)
print(f"Database Host: {DB_HOST}")
print(f"Database Name: {DB_NAME}")
print(f"Dataset File:  {file_path.name} ({file_path.stat().st_size / (1024*1024):.1f} MB)")

# 4. Initialize empty table schema in MySQL
print("\n[Step 1/3] Preparing table schema 'stg_application_train'...")
sample_df = pd.read_csv(file_path, nrows=50)
sample_df.head(0).to_sql(
    name="stg_application_train",
    con=engine,
    if_exists="replace",
    index=False
)
print("Table structure created successfully.")

# 5. High-speed chunked ingestion using LOAD DATA LOCAL INFILE
# Chunking into ~15,000 rows keeps each packet under 8MB, safely within
# RDS's 64MB max_allowed_packet and 30-second net_read_timeout.
CHUNK_SIZE = 15000
temp_chunk_file = Path("/tmp/app_train_chunk.csv")

print(f"\n[Step 2/3] Uploading records in batches of {CHUNK_SIZE:,} rows...")
start_time = time.time()
total_loaded = 0

raw_conn = engine.raw_connection()
cursor = raw_conn.cursor()

try:
    with open(file_path, "r", encoding="utf-8") as f_in:
        header = f_in.readline()
        chunk_idx = 1
        
        while True:
            lines = [f_in.readline() for _ in range(CHUNK_SIZE)]
            lines = [line for line in lines if line]
            
            if not lines:
                break
            
            # Write chunk to temp file
            with open(temp_chunk_file, "w", encoding="utf-8") as f_out:
                f_out.write(header)
                f_out.writelines(lines)
            
            chunk_rows = len(lines)
            chunk_start = time.time()
            
            # Load chunk into MySQL
            csv_path_clean = str(temp_chunk_file.resolve()).replace("\\", "/")
            sql = f"""
            LOAD DATA LOCAL INFILE '{csv_path_clean}'
            INTO TABLE stg_application_train
            FIELDS TERMINATED BY ','
            OPTIONALLY ENCLOSED BY '\"'
            LINES TERMINATED BY '\\n'
            IGNORE 1 LINES
            """
            cursor.execute(sql)
            raw_conn.commit()
            
            total_loaded += chunk_rows
            chunk_elapsed = time.time() - chunk_start
            print(
                f"  -> Batch {chunk_idx:02d}: Loaded {chunk_rows:,} rows "
                f"(Total: {total_loaded:,}) in {chunk_elapsed:.1f}s",
                flush=True
            )
            chunk_idx += 1

    total_elapsed = time.time() - start_time
    print(f"\nAll batches uploaded successfully in {total_elapsed:.1f}s!")

except Exception as err:
    raw_conn.rollback()
    print(f"\nUpload error: {err}")
    raise

finally:
    cursor.close()
    raw_conn.close()
    if temp_chunk_file.exists():
        temp_chunk_file.unlink()

# 6. Verify total row count in MySQL RDS
print("\n[Step 3/3] Verifying database records...")
with engine.connect() as conn:
    final_count = conn.execute(
        text("SELECT COUNT(*) FROM stg_application_train")
    ).scalar()
    print("=" * 60)
    print(f"VERIFICATION SUCCESSFUL: {final_count:,} records in 'stg_application_train'")
    print("=" * 60)

engine.dispose()

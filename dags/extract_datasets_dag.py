import os
import boto3
import sys
import time

from datetime import datetime
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator

sys.path.insert(0, "/opt/airflow/extract")
from config import DATASET_CONFIGS

default_args = {
    "owner": "default",
    "retries": 2,
    "retry_delay": 5,
    "email_on_failure": False,
}

def verify_s3_upload(ds: str):
    bucket = os.environ["S3_BUCKET_NAME"]
    bucket_folder = os.environ["S3_BUCKET_FOLDER"]
    s3 = boto3.client("s3")
    run_year = ds[:4]
    missing_files = []
    for dataset_id in DATASET_CONFIGS:
        key = f"{bucket_folder}/{DATASET_CONFIGS[dataset_id]['name']}/{run_year}/data.parquet"
        try:
            head = s3.head_object(Bucket=bucket, Key=key)
        except s3.exceptions.ClientError:
            missing_files.append(f"s3://{bucket}/{key}")
            continue
        size_mb = head["ContentLength"] / (1024 * 1024)
        print(f"Verified s3://{bucket}/{key} ({size_mb:.2f} MB)")
 
    if missing_files:
        raise RuntimeError(f"Missing expected objects in S3: {missing_files}")

def trigger_glue_crawler():
    glue = boto3.client("glue")
    crawler_name = os.environ["GLUE_CRAWLER_NAME"]

    state = glue.get_crawler(Name=crawler_name)["Crawler"]["State"]
    if state != "READY":
        raise RuntimeError(
            f"Crawler '{crawler_name}' is not READY (state: {state}) — "
            "a previous run may still be in progress."
        )
    glue.start_crawler(Name=crawler_name)
    print(f"Started crawler '{crawler_name}'")

def wait_for_crawler():
    glue = boto3.client("glue")
    crawler_name = os.environ["GLUE_CRAWLER_NAME"]
    max_wait_seconds = 600
    poll_interval = 15
    waited = 0

    while waited < max_wait_seconds:
        crawler = glue.get_crawler(Name=crawler_name)["Crawler"]
        state = crawler["State"]
        if state == "READY":
            last_crawl = crawler.get("LastCrawl", {})
            status = last_crawl.get("Status")
            print(f"Crawler finished, crawl status: {status}")
            if status == "FAILED":
                raise RuntimeError(f"Glue crawler run failed: {last_crawl.get('ErrorMessage')}")
            return
        print(f"Crawler state: {state}, waiting {poll_interval}s")
        time.sleep(poll_interval)
        waited += poll_interval

    raise TimeoutError(f"Crawler '{crawler_name}' did not finish within {max_wait_seconds}s")

def _run_redshift_sql(client, workgroup, database, sql, fetch_scalar=False, max_wait_seconds=120):
    resp = client.execute_statement(WorkgroupName=workgroup, Database=database, Sql=sql)
    statement_id = resp["Id"]

    waited = 0
    while waited < max_wait_seconds:
        desc = client.describe_statement(Id=statement_id)
        status = desc["Status"]
        if status == "FINISHED":
            if fetch_scalar:
                result = client.get_statement_result(Id=statement_id)
                return int(result["Records"][0][0]["longValue"])
            return None
        if status in ("FAILED", "ABORTED"):
            raise RuntimeError(f"Redshift statement failed: {desc.get('Error')}")
        time.sleep(3)
        waited += 3

    raise TimeoutError("Redshift statement did not complete in time")

def ensure_external_schema():
    redshift = boto3.client("redshift-data")
    workgroup = os.environ["REDSHIFT_WORKGROUP_NAME"]
    database = os.environ["REDSHIFT_DATABASE_NAME"]
    glue_db = os.environ["GLUE_DATABASE_NAME"]
    role_arn = os.environ["REDSHIFT_SPECTRUM_ROLE_ARN"]

    sql = (
        "CREATE EXTERNAL SCHEMA IF NOT EXISTS raw_external "
        f"FROM DATA CATALOG DATABASE '{glue_db}' "
        f"IAM_ROLE '{role_arn}';"
    )
    _run_redshift_sql(redshift, workgroup, database, sql)
    print("Confirmed external schema 'raw_external' exists")

def verify_redshift_tables():
    glue_db = os.environ["GLUE_DATABASE_NAME"]
    glue = boto3.client("glue")
    tables = glue.get_tables(DatabaseName=glue_db)["TableList"]

    if not tables:
        raise RuntimeError(f"No tables found in Glue database '{glue_db}'")

    redshift = boto3.client("redshift-data")
    workgroup = os.environ["REDSHIFT_WORKGROUP_NAME"]
    database = os.environ["REDSHIFT_DATABASE_NAME"]
    
    for table in tables:
        table_name = table["Name"]
        sql = f'SELECT COUNT(*) FROM raw_external."{table_name}";'
        row_count = _run_redshift_sql(redshift, workgroup, database, sql, fetch_scalar=True)
        print(f"raw_external.{table_name}: {row_count} rows")
        if row_count == 0:
            raise RuntimeError(f"Table '{table_name}' has 0 rows in Redshift Spectrum")

with DAG(
    dag_id="extract_business_licenses",
    description="Pull NYC data from Socrata into S3 raw bucket",
    default_args=default_args,
    start_date=datetime(2025, 1, 1),
    schedule="@yearly",
    catchup=False,
    max_active_runs=1,
    tags=["nyc-business-analytics", "extract"],
) as dag:

    extract_task = BashOperator(
        task_id="extract_business_licenses",
        bash_command="cd /opt/airflow/extract && python extract.py --run-date {{ ds }}",
    )

    verify_task = PythonOperator(
        task_id="verify_s3_upload",
        python_callable=verify_s3_upload,
    )

    trigger_crawler_task = PythonOperator(
        task_id="trigger_glue_crawler",
        python_callable=trigger_glue_crawler,
    )

    wait_crawler_task = PythonOperator(
        task_id="wait_for_crawler",
        python_callable=wait_for_crawler,
    )

    ensure_schema_task = PythonOperator(
        task_id="ensure_external_schema",
        python_callable=ensure_external_schema,
    )

    verify_redshift_task = PythonOperator(
        task_id="verify_redshift_tables",
        python_callable=verify_redshift_tables,
    )

    (extract_task
        >> verify_task
        >> trigger_crawler_task
        >> wait_crawler_task
        >> ensure_schema_task
        >> verify_redshift_task)
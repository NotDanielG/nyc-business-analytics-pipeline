import requests
import os
import json
import boto3
import pandas as pd
import io
import time
import argparse
from datetime import date
from botocore.exceptions import ClientError
from dotenv import load_dotenv
from config import DATASET_CONFIGS

def get_dataset(socrata_url, dataset_id, dataset_name, socrata_token, socrata_secret_id, run_year, checkpoint=None, page_size=1000, max_retries=5, delay=5):
    print(f"Fetching for dataset: {dataset_name}")
    results = []
    attempt = 0
    last_watermark = checkpoint if checkpoint else "1970-01-01T00:00:00.000"
    offset = 0
    config = DATASET_CONFIGS[dataset_id]
    max_retries = config['max_retries'] if 'max_retries' in config else 5

    while True:
        query = f"SELECT *"
        if config['strategy'] == "batch-keyset":
            order_column = config['order_column']
            query = f"SELECT * WHERE {order_column} > '{last_watermark}' ORDER BY {order_column} LIMIT {page_size} OFFSET {offset}"

            if 'created_column' in config and 'has_year_limit' in config and config['has_year_limit']:
                year_start = f"{run_year}-01-01T00:00:00.000"
                year_end = f"{int(run_year) + 1}-01-01T00:00:00.000"
                created_column = config['created_column']
                query = f"SELECT * WHERE {order_column} > '{last_watermark}' AND {created_column} >= '{year_start}' AND {created_column} < '{year_end}' ORDER BY {order_column} LIMIT {page_size}"
            

        print(query)
        response = None
        try:
            response = requests.post(
                f"{socrata_url}/{dataset_id}/query.json",
                auth=(socrata_token, socrata_secret_id),
                timeout=30,
                json={
                    "query": query,
                }
            )
        except Exception as e:
            if attempt >= max_retries: 
                print(f"SOCRATA TimeoutError, received {len(results)} rows")
                return results, last_watermark
            wait = delay * (2 ** attempt)
            print(f"SOCRATA TimeoutError, retrying in {wait}s. Attempt #{attempt}/{max_retries}")
            attempt+=1
            time.sleep(wait)
            continue

            
        if attempt >= max_retries:
            raise RuntimeError(f"Query failed after {attempt} retries")
        
        if response.status_code == 400:
            print(response.text)
            wait = delay * (2 ** attempt)
            print(f"Secondary not ready, retrying in {wait}s. Attempt #{attempt}/{max_retries}")
            attempt+=1
            time.sleep(wait)
            continue

        response.raise_for_status()
        batch = response.json()
        if not batch:
            print("No results left found, breaking from loop.")
            break

        if config["strategy"] == "single":
            print(f"Single file strategy, fetched {len(batch)} rows so far")
            return batch, None
        
        results.extend(batch)       
        last_watermark = batch[-1][config['order_column']]
        offset += len(batch)
        
        if "has_limit" in config and config["has_limit"] and len(results) >= config["max_ingested"]:
            return results, last_watermark
        print(f"Fetched {len(results)} rows so far")

    return results, None

def append_to_s3(records, bucket, s3_key, aws_region='us-east-1'):
    if len(records) > 0:
        s3 = boto3.client("s3", region_name=aws_region)
        new_df = pd.DataFrame(records)

        old_parquet = s3.get_object(Bucket=bucket, Key=s3_key)
        old_df = pd.read_parquet(io.BytesIO(old_parquet["Body"].read()))
        combined_df = pd.concat([old_df, new_df], ignore_index=True)

        buffer = io.BytesIO()
        combined_df.to_parquet(buffer, engine="pyarrow", index=False)
        buffer.seek(0)

        s3.upload_fileobj(buffer, bucket, s3_key)
        print(f"Appended {len(new_df)} records, Total {len(combined_df)} records to s3://{bucket}")

def upload_to_s3(records, bucket, s3_key, aws_region='us-east-1'):
    if len(records) > 0:
        df = pd.DataFrame(records)

        buffer = io.BytesIO()
        df.to_parquet(buffer, engine="pyarrow", index=False)
        buffer.seek(0)

        s3 = boto3.client("s3", region_name=aws_region)
        s3.upload_fileobj(buffer, bucket, s3_key)
        print(f"Uploaded {len(df)} records to s3://{bucket}")

def is_file_exist(bucket, s3_key):
    s3 = boto3.client('s3')
    try:
        s3.head_object(Bucket=bucket, Key=s3_key)
        return True
    except ClientError as e:
        if e.response['Error']['Code'] == "404":
            return False
        raise e 
def load_checkpoint(bucket, s3_key):
    s3 = boto3.client('s3')
    try:
        response = s3.get_object(Bucket=bucket, Key=f"{s3_key}/watermark.txt")
        watermark = response['Body'].read().decode('utf-8')
        s3.delete_object(Bucket=bucket, Key=f"{s3_key}/watermark.txt")
        return watermark
    except ClientError as e:
        if e.response['Error']['Code'] == 'NoSuchKey':
            print("No checkpoint file found")
        else:
            print(f"An unexpected error has occurred{e}")
        return None

def save_checkpoint(bucket, s3_key, checkpoint):
    s3_client = boto3.client('s3')
    try:
        s3_client.put_object(Bucket=bucket, Key=f"{s3_key}/watermark.txt", Body=checkpoint)
        print(f"Saved watermark file: {checkpoint}")
    except ClientError as e:
        if e.response['Error']['Code'] == 'NoSuchKey':
            print("No such file found")
        else:
            print(f"An unexpected error has occurred{e}")
            raise

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-date", default=None)
    return parser.parse_args()

def main():
    load_dotenv()

    args = parse_args()
    socrata_token = os.getenv("SOCRATA_KEY_ID")
    socrata_secret_id = os.getenv("SOCRATA_SECRET_KEY")
    socrata_url = os.getenv("SOCRATA_URL")
    bucket = os.getenv("S3_BUCKET_NAME")
    bucket_folder = os.getenv("S3_BUCKET_FOLDER")
    checkpoints_folder = os.getenv("S3_BUCKET_CHECKPOINT")

    run_date = date.today().strftime("%Y")
    if args.run_date:
        run_date = args.run_date[:4]
    else:
        run_date = date.today().strftime("%Y")

    for i, dataset_id in enumerate(DATASET_CONFIGS):
        s3_data_path = f"{bucket_folder}/{DATASET_CONFIGS[dataset_id]['name']}/{run_date}"
        s3_checkpoint_path = f"{checkpoints_folder}/{DATASET_CONFIGS[dataset_id]['name']}/{run_date}"
        checkpoint = load_checkpoint(bucket=bucket, s3_key=s3_checkpoint_path)
        if not is_file_exist(bucket=bucket, s3_key=f"{s3_data_path}/data.parquet") or checkpoint:
            data, last_watermark = get_dataset(
                socrata_url=socrata_url, 
                dataset_id=dataset_id, 
                dataset_name=DATASET_CONFIGS[dataset_id]['name'], 
                socrata_token=socrata_token, 
                socrata_secret_id=socrata_secret_id, 
                run_year=run_date,
                checkpoint=checkpoint)
            if checkpoint:
                append_to_s3(records=data, bucket=bucket, s3_key=f"{s3_data_path}/data.parquet")
            else:    
                upload_to_s3(records=data, bucket=bucket, s3_key=f"{s3_data_path}/data.parquet")

            if last_watermark:
                save_checkpoint(bucket=bucket, s3_key=s3_checkpoint_path, checkpoint=last_watermark)  

if __name__ == "__main__":
    main()

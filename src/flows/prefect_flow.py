from prefect import flow, task
from prefect.logging import get_run_logger
import boto3
from pyspark.sql import SparkSession
from pydeequ.analyzers import *
from pydeequ.verification import *
from pydeequ.checks import CheckLevel

s3_client = boto3.client('s3')

# Initialize Spark session
spark = SparkSession.builder \
    .appName("PyDeequ") \
    .getOrCreate()

@task
def read_from_s3(s3_path):
    df = spark.read.parquet(s3_path)
    return df

@task
def verify_columns(df):
    # Convert pandas DataFrame to Spark DataFrame
    spark_df = spark.createDataFrame(df)
    
    check = Check(spark, CheckLevel.Warning, "Review Check")

    verification_suite = VerificationSuite(spark) \
        .onData(spark_df) \
        .addCheck(
            check.hasMaxLength("main_language", 6)) \
        .run()
    
    return verification_suite

@task
def write_to_s3(df, path):
    df.save_to_disk(path)

@flow
def ecs_flow():
    logger = get_run_logger()
    logger.info("Starting ECS Flow")

    bucket_name = "metaflowpersonal-metaflows3bucket-qjhvdp1sgdsv "
    input_prefix = "output/manual_2/"
    output_prefix = "verified_output/v1/"

    df = read_from_s3(bucket_name + input_prefix)
    verification_result = verify_columns(df)
    logger.info(f"Verification Result: {verification_result}")
    write_to_s3(df, bucket_name + output_prefix)

if __name__ == "__main__":
    ecs_flow()
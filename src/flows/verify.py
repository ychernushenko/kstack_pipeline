import argparse
from logging import Logger

from pyspark import SparkConf
from pyspark.sql import SparkSession
from pydeequ.verification import VerificationSuite
from pydeequ.checks import CheckLevel, Check

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="VErify with PyDeequ")
    parser.add_argument("--input_path", "-i", type=str, required=True, help="S3 path for input")
    parser.add_argument("--output_path", required=True, help="S3 path for output")
    args = parser.parse_args()

    conf = (
        SparkConf()
        .set("spark.app.name", "VerifyWithPyDeequ")
        .set("spark.sql.execution.arrow.pyspark.enabled", "true")
        .set("spark.storage.memoryFraction", "1")
        .set("spark.default.parallelism", "100")
        .set("spark.sql.autoBroadcastJoinThreshold", "20485760")
        .set("spark.sql.broadcastTimeout", "3600")
        .set("spark.sql.shuffle.partitions", "8192")
        .set("spark.python.profile", "true" if args.profile else "false")
    )

    spark = SparkSession.Builder().config(conf=conf).getOrCreate()
    sc = spark.sparkContext
    sc.setCheckpointDir(args.checkpoint_dir)
    log: Logger = spark.sparkContext._jvm.org.apache.log4j.LogManager.getLogger(__name__)

    # Read input data from S3
    df = spark.read.parquet(args.input_path)

    check = Check(spark, CheckLevel.Warning, "Review Check")

    verification_result = VerificationSuite(spark) \
        .onData(df) \
        .addCheck(
            check.hasMaxLength("main_language", 6)) \
        .run()
    
    log.info(f"Verification Result: {verification_result}") # Useful code should go here
    
    df.write.parquet(args.output_path)


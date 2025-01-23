from prefect import flow, task
from prefect.logging import get_run_logger
import boto3

s3_client = boto3.client('s3')
emr_client = boto3.client('emr-serverless')

@task
def submit_emr_job(application_id, job_role_arn, code_bucket_path, s3_script_path, s3_dependencies_path, s3_input_path, s3_output_path):
    response = emr_client.start_job_run(
        applicationId=application_id,
        executionRoleArn=job_role_arn,
        jobDriver={
            'sparkSubmit': {
                'entryPoint': s3_script_path,
                'entryPointArguments': [
                    "--input", s3_input_path, "--output", s3_output_path, "--checkpoint_dir", f"{code_bucket_path}/emr/checkpoint/"
                ],
                'sparkSubmitParameters': f"--conf spark.archives={s3_dependencies_path}#environment --conf spark.emr-serverless.driverEnv.PYSPARK_DRIVER_PYTHON=./environment/bin/python --conf spark.emr-serverless.driverEnv.PYSPARK_PYTHON=./environment/bin/python --conf spark.emr-serverless.executorEnv.PYSPARK_PYTHON=./environment/bin/python --conf spark.local.dir={code_bucket_path}/emr/workdir"
            }
        },
        configurationOverrides={
            'monitoringConfiguration': {
                's3MonitoringConfiguration': {
                    'logUri': f"{code_bucket_path}/emr/logs/"
                }
            }
        }
    )
    return response['jobRunId']

@task
def check_emr_job_status(application_id, job_run_id):
    response = emr_client.get_job_run(
        applicationId=application_id,
        jobRunId=job_run_id
    )
    return response['jobRun']['state']

@flow
def ecs_flow():
    logger = get_run_logger()
    logger.info("Starting ECS Flow")

    code_bucket = "kstack-chernushenko"
    data_bucket = "metaflowpersonal-metaflows3bucket-qjhvdp1sgdsv"

    application_id = "00fpn48edgsod715"
    job_role_arn = "arn:aws:iam::742491319596:role/EMRServerlessExecutionRole"
    s3_input_path = f"s3://{data_bucket}/output/manual_2/"
    s3_output_path = f"s3://{data_bucket}/verified_output/v1/"
    s3_script_path = f"s3://{code_bucket}/src/verify.py"
    code_bucket_path = f"s3://{code_bucket}"
    s3_dependencies_path = f"s3://{code_bucket}/src/pyspark_emr.tar.gz"

    job_run_id = submit_emr_job(
        application_id, 
        job_role_arn,
        code_bucket_path,
        s3_script_path,
        s3_dependencies_path,
        s3_input_path,
        s3_output_path
    )
    logger.info(f"Submitted EMR job with ID: {job_run_id}")

    # Optionally, you can wait for the job to complete and check its status
    import time
    while True:
        status = check_emr_job_status(application_id, job_run_id)
        logger.info(f"Job status: {status}")
        if status in ["SUCCESS", "FAILED", "CANCELLED"]:
            break
        time.sleep(30)

if __name__ == "__main__":
    ecs_flow()
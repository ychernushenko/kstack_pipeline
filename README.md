# Prefect agent image  
docker build -f Dockerfile_agent --platform linux/amd64 -t prefect-agent .
docker tag prefect-agent 742491319596.dkr.ecr.eu-central-1.amazonaws.com/prefect-repository-agent:latest  
docker push 742491319596.dkr.ecr.eu-central-1.amazonaws.com/prefect-repository-agent:latest  

# Create Serverless App
`aws emr-serverless create-application \
    --name kstack-dedup \
    --release-label emr-7.6.0 \
    --type Spark \
    --initial-capacity '{"DRIVER":{"workerCount":1,"workerConfiguration":{"cpu":"2vCPU","memory":"8GB"}},"EXECUTOR":{"workerCount":2,"workerConfiguration":{"cpu":"2vCPU","memory":"8GB"}}}'`

# Deploy EMR dependencies (manual step)
aws s3 cp ./src/flows/verify.py s3://kstack-chernushenko/src/verify.py
DOCKER_BUILDKIT=1 docker build --output . .  -f Dockerfile_emr
aws s3 cp pyspark_emr.tar.gz s3://kstack-chernushenko/src/pyspark_emr.tar.gz

# Get Dependencies
poetry export -f requirements.txt --output requirements.txt  --without-hashes
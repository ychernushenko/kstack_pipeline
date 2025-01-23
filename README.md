# Prefect agent image  
docker build -f Dockerfile_agent --platform linux/amd64 -t prefect-agent .
docker tag prefect-agent 742491319596.dkr.ecr.eu-central-1.amazonaws.com/prefect-repository-agent:latest  
docker push 742491319596.dkr.ecr.eu-central-1.amazonaws.com/prefect-repository-agent:latest  
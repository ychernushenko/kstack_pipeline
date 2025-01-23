import argparse
from flows.prefect_flow import ecs_flow

def create_deployment(name, work_pool_name, image, build, push):
    ecs_flow.deploy(
        name,
        work_pool_name=work_pool_name,
        image=image,
        job_variables = {
            "cluster": "arn:aws:ecs:eu-central-1:742491319596:cluster/prefect-cluster"
        },
        build=build,
        push=push
    )

if __name__ == "__main__":
    # Parse input parameters
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", required=True, help="Name of the flow")
    parser.add_argument("--work_pool_name", required=True, help="Name of the work pool")
    parser.add_argument("--image", required=False, help="Docker image")
    parser.add_argument("--build", type=bool, default=False, help="Build flag")
    parser.add_argument("--push", type=bool, default=False, help="Push flag")
    args = parser.parse_args()

    # Call create_deployment with parsed arguments
    create_deployment(args.name, args.work_pool_name, args.image, args.build, args.push)

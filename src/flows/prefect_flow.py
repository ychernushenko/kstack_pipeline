from prefect import flow
from prefect.logging import get_run_logger

@flow
def ecs_flow():
    logger = get_run_logger()
    logger.info("Hello from ECS!!")

if __name__ == "__main__":
    ecs_flow()

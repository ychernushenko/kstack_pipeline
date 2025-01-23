from prefect import flow

@flow
def ecs_flow():
    print("Hello, Prefect on ECS!")

if __name__ == "__main__":
    ecs_flow()

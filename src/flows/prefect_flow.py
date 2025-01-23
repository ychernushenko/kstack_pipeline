from prefect import flow, task

@task
def say_hello():
    print("Hello, Prefect on ECS!")

@flow
def ecs_flow():
    say_hello()

if __name__ == "__main__":
    ecs_flow()

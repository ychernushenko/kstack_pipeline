# Use a Python base image
FROM python:3.9-slim

# Set the working directory
WORKDIR /app

# Install Poetry
RUN pip install --no-cache-dir poetry

# Copy the Poetry files and install dependencies
COPY pyproject.toml poetry.lock ./
RUN poetry install --no-root --only main

# Copy the flow code into the container
COPY src/flows/prefect_flow.py ./

# Set the entry point to run the Prefect flow
CMD ["poetry", "run", "python", "prefect_flow.py"]

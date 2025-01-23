FROM prefecthq/prefect:3-latest

# Set the working directory
WORKDIR /app

# Install Poetry
RUN pip install --no-cache-dir poetry

# Copy the Poetry files and install dependencies
COPY pyproject.toml poetry.lock ./
RUN poetry install --no-root --only main

# Copy the flow code into the container
COPY ./src/ /app/

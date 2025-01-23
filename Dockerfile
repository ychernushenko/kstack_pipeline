FROM prefecthq/prefect:3-latest

# Set the working directory
WORKDIR /app

# Install requirements
COPY ./requirements.txt /app/requirements.txt
RUN pip install -r /app/requirements.txt

# Set the SPARK_VERSION environment variable
ENV SPARK_VERSION=3.1

# Copy the flow code into the container
COPY ./src/ /app/

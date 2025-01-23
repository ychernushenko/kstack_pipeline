FROM prefecthq/prefect:3-latest

# Set the working directory
WORKDIR /app

# Install requirements
COPY ./requirements.txt /requirements.txt
RUN pip install -r /requirements.tx

# Copy the flow code into the container
COPY ./src/ /app/

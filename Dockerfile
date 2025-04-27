# Use an official Python runtime as a parent image
FROM python:3.10-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Set the working directory in the container
WORKDIR /app

# Install system dependencies (if any are needed beyond base Python)
# apt-get update && apt-get install -y --no-install-recommends some-package

# Install Python dependencies
# Copy only requirements first to leverage Docker cache
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code
COPY . .

# Make port 80 available to the world outside this container (uvicorn default)
# The deploy script maps this to HTTP
EXPOSE 80

# Define the command to run the application using uvicorn
# It will bind to 0.0.0.0 to be accessible from outside the container
# Assumes your FastAPI app instance is named 'app' in 'app.py'
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "80"] 
# Use an official Python runtime as a parent image
FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Set the working directory in the container
WORKDIR /app

# Install system dependencies if needed (unlikely for this setup, but good practice)
# RUN apt-get update && apt-get install -y --no-install-recommends some-package && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
# Copy only requirements first to leverage Docker cache
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code into the container
# Ensure faiss_openai_index and static are copied if they exist and are needed
COPY . .

# Expose the port the app runs on (Vercel will map $PORT to this)
EXPOSE 8000

# Define the command to run the application
# Use 0.0.0.0 to allow external connections (within Vercel's network)
# Use port 8000 as defined in EXPOSE
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"] 
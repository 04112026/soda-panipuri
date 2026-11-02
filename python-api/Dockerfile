FROM python:3.12-slim
WORKDIR /app
# Layer 1: dependencies; cached when only app.py changes
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
# Layer 2: application code
COPY app.py ./
EXPOSE 5000
CMD ["python", "app.py"]

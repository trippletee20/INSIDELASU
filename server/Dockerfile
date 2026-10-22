FROM python:3.12-slim
WORKDIR /app
COPY app.py moderate.py entrypoint.py .
RUN chmod 755 /app && chmod 644 /app/*.py && useradd --create-home campus && mkdir /data && chown campus:campus /data
ENV DATABASE_PATH=/data/campus-social.sqlite3 PORT=8080
EXPOSE 8080
CMD ["python", "entrypoint.py"]

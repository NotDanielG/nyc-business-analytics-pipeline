FROM apache/airflow:2.9.3-python3.11

COPY extract/requirements.txt /requirements.txt
RUN pip install --no-cache-dir -r /requirements.txt

USER root
COPY dbt/requirements.txt /dbt-requirements.txt
RUN python3 -m venv /opt/dbt-venv && \
    /opt/dbt-venv/bin/pip install --no-cache-dir -r /dbt-requirements.txt
USER airflow
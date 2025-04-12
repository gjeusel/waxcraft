# N8N

url: https://labforfunfl272gtp-n8n-perso.functions.fnc.fr-par.scw.cloud/home/workflows

[N8N cfg doc](https://docs.n8n.io/hosting/configuration/environment-variables/)
[SCW cli doc](https://cli.scaleway.com/container/#update-an-existing-container)

```bash
scw --profile perso \
  container container update 455edb12-eae8-4e39-aac6-8fa02a736ac4 \
  region="fr-par" privacy=public description="n8n for own consumption" \
  redeploy=true timeout=30s http-option=redirected \
  port=5678 cpu-limit=1000 memory-limit=3072 max-scale=1 \
  health-check.http.path=/ health-check.interval=30s health-check.failure-threshold=6 \
  \
  environment-variables.DB_TYPE=postgresdb \
  environment-variables.DB_POSTGRESDB_DATABASE=n8n \
  environment-variables.DB_POSTGRESDB_HOST=7df34944-65bc-4c57-a772-6d76d52870fa.pg.sdb.fr-par.scw.cloud \
  environment-variables.DB_POSTGRESDB_PORT=5432 \
  environment-variables.DB_POSTGRESDB_USER=85a9d563-47d5-4d0f-b754-f82ce827ad58 \
  environment-variables.DB_POSTGRESDB_SCHEMA=public \
  environment-variables.DB_POSTGRESDB_CONNECTION_TIMEOUT=60000 \
  environment-variables.DB_POSTGRESDB_POOL_SIZE=50 \
  environment-variables.DB_POSTGRESDB_SSL_ENABLED=true \
  environment-variables.DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=true \
  \
  environment-variables.N8N_DIAGNOSTICS_ENABLED=false \
  environment-variables.N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false \
  environment-variables.N8N_HIRING_BANNER_ENABLED=false \
  environment-variables.N8N_TEMPLATES_ENABLED=true \
  environment-variables.GENERIC_TIMEZONE="Europe/Paris" \
  environment-variables.GENERIC_TZ="Europe/Paris" \
  \
  environment-variables.N8N_RUNNERS_ENABLED=false \
  environment-variables.N8N_RUNNERS_MAX_CONCURRENCY=50 \
  environment-variables.N8N_RUNNERS_TASK_TIMEOUT=120 \
  environment-variables.N8N_RUNNERS_HEARTBEAT_INTERVAL=30 \
  \
  environment-variables.N8N_HOST=labforfunfl272gtp-n8n-perso.functions.fnc.fr-par.scw.cloud \
  environment-variables.N8N_PROTOCOL=https \
  environment-variables.N8N_PORT=5678 \
  environment-variables.WEBHOOK_URL=https://labforfunfl272gtp-n8n-perso.functions.fnc.fr-par.scw.cloud/ \
  \
  environment-variables.N8N_EXTERNAL_STORAGE_S3_HOST=n8n-perso.s3.fr-par.scw.cloud \
  environment-variables.N8N_EXTERNAL_STORAGE_S3_BUCKET_NAME=n8n-perso \
  environment-variables.N8N_EXTERNAL_STORAGE_S3_BUCKET_REGION=fr-par \
  environment-variables.N8N_EXTERNAL_STORAGE_S3_ACCESS_KEY=SCWNRNQ1P0077DYQVTYS \
  \
  secret-environment-variables.0.key=DB_POSTGRESDB_PASSWORD \
  secret-environment-variables.0.value=${N8N_PERSO_DB_PWD} \
  secret-environment-variables.1.key=N8N_ENCRYPTION_KEY \
  secret-environment-variables.1.value=${N8N_PERSO_ENCRYPTION_KEY} \
  secret-environment-variables.2.key=N8N_EXTERNAL_STORAGE_S3_ACCESS_SECRET \
  secret-environment-variables.2.value=${N8N_PERSO_API_SECRET_KEY} \
  \
  environment-variables.N8N_LOG_LEVEL=info \
  environment-variables.DB_LOGGING_ENABLED=true \
  environment-variables.DB_LOGGING_OPTIONS=warn \
  environment-variables.CODE_ENABLE_STDOUT=true
```

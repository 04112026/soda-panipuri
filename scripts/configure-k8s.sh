#!/usr/bin/env bash
set -euo pipefail
# Run from repository root after Terraform infrastructure apply.
host=$(terraform -chdir=terraform/infra output -raw db_host)
secret=$(terraform -chdir=terraform/infra output -raw db_secret_arn)
export DB_HOST="$host"
kubectl create namespace training --dry-run=client -o yaml | kubectl apply -f -
# Do not enable shell tracing. Server-side apply avoids a last-applied secret annotation.
aws secretsmanager get-secret-value --secret-id "$secret" --query SecretString --output text |
  jq -c --arg host "$host" '{apiVersion:"v1",kind:"Secret",metadata:{name:"training-db",namespace:"training"},type:"Opaque",data:{DB_HOST:($host|@base64),DB_NAME:("training"|@base64),DB_USER:(.username|@base64),DB_PASSWORD:(.password|@base64)}}' |
  kubectl apply --server-side --field-manager=training-ci -f -

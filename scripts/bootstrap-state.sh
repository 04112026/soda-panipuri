#!/usr/bin/env bash
set -euo pipefail
: "${STATE_BUCKET:?Missing Terraform state bucket name}"
: "${AWS_REGION:?Missing AWS region}"
account=$(aws sts get-caller-identity --query Account --output text)

# Only create a bucket if it is not already accessible to this account.
# CreateBucket outside us-east-1 will fail rather than overwrite a bucket
# owned by someone else. All modifications below verify account ownership.
if ! aws s3api head-bucket --bucket "$STATE_BUCKET" --expected-bucket-owner "$account"; then
  aws s3api create-bucket --bucket "$STATE_BUCKET" --region "$AWS_REGION" \
    --create-bucket-configuration "LocationConstraint=$AWS_REGION"
fi
region=$(aws s3api get-bucket-location --bucket "$STATE_BUCKET" --expected-bucket-owner "$account" --query LocationConstraint --output text)
if [[ "$region" != "$AWS_REGION" ]]; then
  echo "State bucket must be in $AWS_REGION; found $region" >&2
  exit 1
fi
aws s3api put-public-access-block --bucket "$STATE_BUCKET" --expected-bucket-owner "$account" \
  --public-access-block-configuration 'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'
aws s3api put-bucket-versioning --bucket "$STATE_BUCKET" --expected-bucket-owner "$account" \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "$STATE_BUCKET" --expected-bucket-owner "$account" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
echo "Terraform state bucket ready: $STATE_BUCKET"

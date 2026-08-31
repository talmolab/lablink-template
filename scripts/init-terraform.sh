#!/bin/bash
# Helper script to initialize OpenTofu with bucket from config.yaml
#
# Usage: ./scripts/init-terraform.sh [dev|test|ci-test|prod]   (default: dev)
# Runs from any directory: it cd's to lablink-infrastructure/ itself, which is where
# `tofu init` has to run. It leaves you nowhere — run tofu from that directory after.

set -e

# Work from the infrastructure directory no matter where the caller is: that is
# where `tofu init` has to run, and config/ and backend-*.hcl are relative to it.
# Without this, running from the repo root reports "config/config.yaml not found"
# and tells you to create a file that already exists.
cd "$(dirname "${BASH_SOURCE[0]}")/../lablink-infrastructure" || exit 1

ENVIRONMENT=${1:-dev}

case "$ENVIRONMENT" in
    dev | test | ci-test | prod) ;;
    *)
        echo "Error: unknown environment '$ENVIRONMENT' (expected dev, test, ci-test, or prod)"
        exit 1
        ;;
esac

# Extract bucket name from config.yaml
if [ ! -f "config/config.yaml" ]; then
    echo "Error: config/config.yaml not found!"
    echo "Please copy config/example.config.yaml to config/config.yaml and customize it."
    exit 1
fi

BUCKET_NAME=$(grep "^bucket_name:" config/config.yaml | awk '{print $2}' | tr -d '"' | head -n 1)
REGION=$(grep -A 5 "^app:" config/config.yaml | grep "^  region:" | awk '{print $2}' | tr -d '"' | head -n 1)

if [ -z "$BUCKET_NAME" ] || [ "$BUCKET_NAME" = "YOUR-UNIQUE-SUFFIX" ]; then
    echo "Error: Please set a valid bucket_name in config/config.yaml"
    exit 1
fi

if [ -z "$REGION" ]; then
    echo "Error: Please set a valid region in config/config.yaml"
    exit 1
fi

echo "Initializing OpenTofu for $ENVIRONMENT environment"
echo "Using S3 bucket: $BUCKET_NAME"
echo "Using region: $REGION"

# -reconfigure because selecting an environment is this script's whole job: each
# environment is a separate S3 key, so switching between them must repoint the
# backend, not migrate state from one key onto another. Without it, any switch
# (and the first init after dev gained a backend) dies with "Backend
# configuration changed".
tofu init -reconfigure \
    -backend-config="backend-${ENVIRONMENT}.hcl" \
    -backend-config="bucket=$BUCKET_NAME" \
    -backend-config="region=$REGION"

echo "OpenTofu initialized successfully in $(pwd)"
echo "Run tofu plan/apply from that directory."

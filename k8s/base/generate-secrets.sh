#!/bin/bash
# Generate Kubernetes secrets with strong random values
# Usage: ./generate-secrets.sh [namespace]

set -e

NAMESPACE="${1:-evidenceos}"
SECRETS_FILE="secrets.yaml"

echo "🔐 Generating Kubernetes secrets for namespace: $NAMESPACE"
echo ""

# Check if secrets.yaml already exists
if [ -f "$SECRETS_FILE" ]; then
    read -p "⚠️  secrets.yaml already exists. Overwrite? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Aborted. Existing secrets.yaml kept."
        exit 1
    fi
fi

# Generate strong random values
echo "Generating secure random values..."
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)
JWT_SECRET=$(openssl rand -base64 64 | tr -d '/+=' | cut -c1-64)
ADMIN_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)
ANALYST_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)

# Create secrets.yaml from template
cat > "$SECRETS_FILE" <<EOF
# SECURITY WARNING: This file contains sensitive credentials!
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# DO NOT commit this file to version control!

apiVersion: v1
kind: Secret
metadata:
  name: evidenceos-secrets
  namespace: $NAMESPACE
  labels:
    app: evidenceos
type: Opaque
stringData:
  # Database credentials
  postgres-user: evidenceos
  postgres-password: $POSTGRES_PASSWORD
  database-url: postgresql://evidenceos:$POSTGRES_PASSWORD@postgres-service:5432/evidenceos

  # JWT secret (64 characters)
  jwt-secret: $JWT_SECRET

  # Admin initial credentials
  admin-username: admin
  admin-password: $ADMIN_PASSWORD
  analyst-password: $ANALYST_PASSWORD

  # CORS allowed origins (update for your domain)
  cors-allowed-origins: https://evidenceos.com,https://app.evidenceos.com
EOF

# Set restrictive permissions
chmod 600 "$SECRETS_FILE"

echo ""
echo "✅ Secrets generated successfully!"
echo ""
echo "📋 IMPORTANT: Save these credentials securely!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Admin Username:    admin"
echo "Admin Password:    $ADMIN_PASSWORD"
echo "Analyst Password:  $ANALYST_PASSWORD"
echo "Postgres Password: $POSTGRES_PASSWORD"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💾 Store these credentials in a password manager NOW!"
echo ""
echo "🚀 Next steps:"
echo "   1. Store the credentials above securely"
echo "   2. Apply secrets: kubectl apply -f $SECRETS_FILE"
echo "   3. Verify: kubectl get secret evidenceos-secrets -n $NAMESPACE"
echo ""
echo "⚠️  Remember: secrets.yaml is gitignored and should NEVER be committed!"

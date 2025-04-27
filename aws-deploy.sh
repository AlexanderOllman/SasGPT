#!/usr/bin/env bash
set -euo pipefail

# ── CONFIGURATION ─────────────────────────────────────────────────
AWS_REGION="us-east-1"
SERVICE_NAME=""
DOMAIN=""
YEARS=1

# ── AWS CREDENTIALS & REGION ───────────────────────────────────────
echo "👉 AWS Configuration"
read -rp "Enter AWS Access Key ID: " AWS_ACCESS_KEY_ID
read -rsp "Enter AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
echo "" # Add a newline after hidden input
read -rp "Enter AWS Session Token (optional, press ENTER if none): " AWS_SESSION_TOKEN
read -rp "Enter AWS Region [${AWS_REGION}]: " USER_AWS_REGION

# Use user input or default region
AWS_REGION="${USER_AWS_REGION:-$AWS_REGION}"

# Export credentials and region for aws cli commands
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_REGION
export AWS_DEFAULT_REGION="$AWS_REGION" # Many tools use this variable
if [[ -n "$AWS_SESSION_TOKEN" ]]; then
  export AWS_SESSION_TOKEN
fi
echo "✓ AWS credentials and region configured for this session."
echo "" # Add spacing

# ── UTILS ─────────────────────────────────────────────────────────

function pause() {
  read -rp "Press ENTER to continue..."
}

# ── 0) INSTALL AWS CLI V2 IF NEEDED ────────────────────────────────

if ! command -v aws >/dev/null 2>&1 || [[ "$(aws --version 2>&1)" != aws-cli/2* ]]; then
  echo "🔧 Installing AWS CLI v2..."
  OS=$(uname -s)
  ARCH=$(uname -m)

  if [[ "$OS" == "Linux" ]]; then
    # Ensure unzip
    if ! command -v unzip >/dev/null 2>&1; then
      echo "  • Installing unzip..."
      if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y unzip
      elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y unzip
      fi
    fi

    if [[ "$ARCH" == "x86_64" ]]; then
      curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
      unzip awscliv2.zip
      sudo ./aws/install
    elif [[ "$ARCH" =~ ^(aarch64|arm64)$ ]]; then
      echo "  • ARM64 detected—falling back to AWS CLI v1 via pip"
      python3 -m pip install --upgrade awscli
    else
      echo "  • Unknown architecture $ARCH—skipping AWS CLI install"
    fi

  elif [[ "$OS" == "Darwin" ]]; then
    if command -v brew >/dev/null 2>&1; then
      brew install awscli
    else
      curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
      sudo installer -pkg AWSCLIV2.pkg -target /
    fi

  else
    echo "⚠️ Unsupported OS: $OS. Please install AWS CLI manually."
  fi
fi

# ── 1) DOMAIN REGISTRATION ─────────────────────────────────────────

echo "👉 Step 1: Register your domain"
read -rp "Domain to register (e.g. example.com): " DOMAIN
read -rp "Duration (years): " YEARS

echo "Now I'll collect your contact info for ICANN registration."
read -rp "First Name: " FIRST_NAME
read -rp "Last Name:  " LAST_NAME
read -rp "Email:      " EMAIL
read -rp "Phone (E.164, e.g. +15551234567): " PHONE
read -rp "Street Address: " ADDR1
read -rp "City:           " CITY
read -rp "State/Region:   " STATE
read -rp "Postal Code:    " ZIP
read -rp "Country Code (2-letter ISO, e.g. US, AU): " CC

echo "Checking availability for ${DOMAIN}…"
aws route53domains check-domain-availability \
  --region "$AWS_REGION" \
  --domain-name "$DOMAIN" \
  --query 'Availability' --output text

read -rp "Domain available? (y/N): " OK
if [[ "${OK,,}" != "y" ]]; then
  echo "Exiting—domain not available." && exit 1
fi

cat > register-domain.json <<EOF
{
  "DomainName": "${DOMAIN}",
  "DurationInYears": ${YEARS},
  "AutoRenew": true,
  "AdminContact": {
    "FirstName": "${FIRST_NAME}",
    "LastName": "${LAST_NAME}",
    "ContactType": "PERSON",
    "Email": "${EMAIL}",
    "AddressLine1": "${ADDR1}",
    "City": "${CITY}",
    "State": "${STATE}",
    "CountryCode": "${CC}",
    "ZipCode": "${ZIP}",
    "PhoneNumber": "${PHONE}"
  },
  "RegistrantContact": {
    "FirstName": "${FIRST_NAME}",
    "LastName": "${LAST_NAME}",
    "ContactType": "PERSON",
    "Email": "${EMAIL}",
    "AddressLine1": "${ADDR1}",
    "City": "${CITY}",
    "State": "${STATE}",
    "CountryCode": "${CC}",
    "ZipCode": "${ZIP}",
    "PhoneNumber": "${PHONE}"
  },
  "TechContact": {
    "FirstName": "${FIRST_NAME}",
    "LastName": "${LAST_NAME}",
    "ContactType": "PERSON",
    "Email": "${EMAIL}",
    "AddressLine1": "${ADDR1}",
    "City": "${CITY}",
    "State": "${STATE}",
    "CountryCode": "${CC}",
    "ZipCode": "${ZIP}",
    "PhoneNumber": "${PHONE}"
  },
  "PrivacyProtectAdminContact": true,
  "PrivacyProtectRegistrantContact": true,
  "PrivacyProtectTechContact": true
}
EOF

echo "Registering domain ${DOMAIN}…"
aws route53domains register-domain \
  --region "$AWS_REGION" \
  --cli-input-json file://register-domain.json

echo "✅ Registration submitted. Track status with:"
echo "    aws route53domains get-domain-detail --region $AWS_REGION --domain-name $DOMAIN"
pause

# ── 2) LIGHTSAIL CONTAINER SERVICE ─────────────────────────────────

echo "👉 Step 2: Create Lightsail container service"
read -rp "Service name: " SERVICE_NAME

aws lightsail create-container-service \
  --service-name "$SERVICE_NAME" \
  --power micro \
  --scale 1

pause

# ── 3) BUILD & PUSH DOCKER IMAGE ───────────────────────────────────

echo "👉 Step 3: Build & push Docker image"
docker build -t "$SERVICE_NAME:latest" .
aws lightsail push-container-image \
  --region "$AWS_REGION" \
  --service-name "$SERVICE_NAME" \
  --label app \
  --image "$SERVICE_NAME:latest"

pause

# ── 4) DEPLOY TO LIGHTSAIL ─────────────────────────────────────────

echo "👉 Step 4: Deploy container"
cat > deploy.json <<EOF
{
  "serviceName": "$SERVICE_NAME",
  "containers": {
    "app": {
      "image": ":$SERVICE_NAME.app.1",
      "ports": { "80": "HTTP" }
    }
  },
  "publicEndpoint": {
    "containerName": "app",
    "containerPort": 80
  }
}
EOF

aws lightsail create-container-service-deployment \
  --cli-input-json file://deploy.json

pause

# ── 5) POINT DOMAIN DNS ────────────────────────────────────────────

echo "👉 Step 5: Create DNS record"
aws lightsail create-domain-entry \
  --domain-name "$DOMAIN" \
  --domain-entry name="$DOMAIN",target="$(aws lightsail get-container-service \
    --service-name "$SERVICE_NAME" \
    --region "$AWS_REGION" \
    --query 'containerService.publicDomainName' \
    --output text)",type=A,isAlias=true

echo "🎉 Done! Allow DNS 10–30 minutes, then visit: https://${DOMAIN}"

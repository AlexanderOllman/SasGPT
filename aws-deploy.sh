#!/usr/bin/env bash
set -euo pipefail

# ── CONFIGURATION ─────────────────────────────────────────────────
CONFIG_FILE=".deploy_config.env"
AWS_REGION="us-east-1" # Default region
SERVICE_NAME=""
DOMAIN=""
YEARS=1

# ── LOAD OR GET CONFIGURATION ──────────────────────────────────────

# Function to prompt for and save credentials/info
prompt_and_save_config() {
  echo "👉 AWS Configuration"
  read -rp "Enter AWS Access Key ID: " AWS_ACCESS_KEY_ID
  read -rsp "Enter AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
  echo "" # Add a newline after hidden input
  read -rp "Enter AWS Session Token (optional, press ENTER if none): " AWS_SESSION_TOKEN
  read -rp "Enter AWS Region [${AWS_REGION}]: " USER_AWS_REGION
  AWS_REGION="${USER_AWS_REGION:-$AWS_REGION}" # Use user input or default

  echo ""
  echo "👉 Domain Registration & ICANN Contact Info"
  read -rp "Domain to register (e.g. example.com): " DOMAIN
  read -rp "Duration (years) [${YEARS}]: " USER_YEARS
  YEARS="${USER_YEARS:-$YEARS}"
  echo "Now I'll collect your contact info for ICANN registration."
  read -rp "First Name: " FIRST_NAME
  read -rp "Last Name:  " LAST_NAME
  read -rp "Email:      " EMAIL
  read -rp "Phone (Format: +<country_code>.<number>, e.g. +1.5551234567): " PHONE
  read -rp "Street Address: " ADDR1
  read -rp "City:           " CITY
  read -rp "State/Region:   " STATE
  read -rp "Postal Code:    " ZIP
  read -rp "Country Code (2-letter ISO, e.g. US, AU): " CC

  # Save to config file
  echo "Saving configuration to ${CONFIG_FILE}..."
  cat > "$CONFIG_FILE" <<EOF
# AWS Credentials and Configuration
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN}"
AWS_REGION="${AWS_REGION}"

# Domain and Contact Information
DOMAIN="${DOMAIN}"
YEARS="${YEARS}"
FIRST_NAME="${FIRST_NAME}"
LAST_NAME="${LAST_NAME}"
EMAIL="${EMAIL}"
PHONE="${PHONE}"
ADDR1="${ADDR1}"
CITY="${CITY}"
STATE="${STATE}"
ZIP="${ZIP}"
CC="${CC}"
EOF
  chmod 600 "$CONFIG_FILE" # Restrict permissions
  echo "✓ Configuration saved."
  echo ""
}

# Check if config file exists and load if user agrees
if [[ -f "$CONFIG_FILE" ]]; then
  echo "ℹ️ Found existing configuration in ${CONFIG_FILE}:"
  # Source the file to load variables (careful with execution)
  # Temporarily disable exit on error in case file is malformed
  set +e
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
  set -e

  # Display non-sensitive loaded values for confirmation
  echo "  AWS Access Key ID: ${AWS_ACCESS_KEY_ID}"
  echo "  AWS Region:        ${AWS_REGION}"
  echo "  Domain:            ${DOMAIN}"
  echo "  Years:             ${YEARS}"
  echo "  Email:             ${EMAIL}"
  # Add other non-sensitive fields if needed

  read -rp "Use these saved settings? (y/N): " USE_SAVED
  if [[ "${USE_SAVED,,}" == "y" ]]; then
    echo "✓ Using saved configuration."
    echo ""
  else
    echo "🧹 Clearing old config and prompting for new values."
    rm -f "$CONFIG_FILE" # Remove old file before prompting
    prompt_and_save_config
  fi
else
  echo "ℹ️ No configuration file found. Prompting for details..."
  prompt_and_save_config
fi


# ── EXPORT AWS CREDENTIALS ─────────────────────────────────────────
# Ensure required AWS vars are exported if loaded from file or newly entered
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

# ── ENSURE LIGHTSAILCTL PLUGIN ─────────────────────────────────────

ensure_lightsailctl() {
  # Check if already in PATH
  if command -v lightsailctl >/dev/null 2>&1; then
    echo "✓ Lightsail Control plugin (lightsailctl) found in PATH."
    return 0
  fi

  # Check if previously downloaded by this script
  PLUGIN_DIR="$(pwd)/.lightsailctl_plugin_temp"
  if [[ -x "$PLUGIN_DIR/lightsailctl" || -x "$PLUGIN_DIR/lightsailctl.exe" ]]; then
    echo "✓ Found previously downloaded lightsailctl plugin."
    export PATH="$PLUGIN_DIR:$PATH"
    echo "✓ Added $PLUGIN_DIR to PATH for this session."
    return 0
  fi

  # If not found, attempt download
  echo "ℹ️ Lightsail Control plugin (lightsailctl) not found. Attempting to download..."
  OS=$(uname -s)
  ARCH=$(uname -m)
  mkdir -p "$PLUGIN_DIR"
  PLUGIN_PATH="$PLUGIN_DIR/lightsailctl"
  DOWNLOAD_URL=""

  case "$OS" in
    Linux)
      case "$ARCH" in
        x86_64) DOWNLOAD_URL="https://s3.us-west-2.amazonaws.com/lightsailctl/latest/linux-amd64/lightsailctl" ;;
        aarch64 | arm64) DOWNLOAD_URL="https://s3.us-west-2.amazonaws.com/lightsailctl/latest/linux-arm64/lightsailctl" ;;
        *) echo "❌ Unsupported Linux architecture for lightsailctl: $ARCH" >&2; rm -rf "$PLUGIN_DIR"; return 1 ;;
      esac
      ;;
    Darwin)
      # Docs only list amd64 for macOS. ARM might work via Rosetta 2.
      if [[ "$ARCH" == "arm64" ]]; then
         echo "ℹ️ Using macOS AMD64 build for lightsailctl on ARM64 architecture (requires Rosetta 2)."
      elif [[ "$ARCH" != "x86_64" ]]; then
         echo "❌ Unsupported macOS architecture: $ARCH" >&2; rm -rf "$PLUGIN_DIR"; return 1
      fi
      DOWNLOAD_URL="https://s3.us-west-2.amazonaws.com/lightsailctl/latest/darwin-amd64/lightsailctl"
      ;;
    CYGWIN*|MINGW32*|MSYS*|MINGW*)
      # Assuming Windows AMD64
      PLUGIN_PATH="$PLUGIN_DIR/lightsailctl.exe"
      DOWNLOAD_URL="https://s3.us-west-2.amazonaws.com/lightsailctl/latest/windows-amd64/lightsailctl.exe"
      ;;
    *)
      echo "❌ Unsupported OS for automatic lightsailctl download: $OS" >&2
      echo "Please install it manually from: https://lightsail.aws.amazon.com/ls/docs/en_us/articles/amazon-lightsail-install-software" >&2
      rm -rf "$PLUGIN_DIR"
      return 1
      ;;
  esac

  echo "  Downloading from $DOWNLOAD_URL..."
  # Use curl with flags: -f (fail silently on HTTP errors), -s (silent), -S (show error), -L (follow redirects)
  if curl -fsSL "$DOWNLOAD_URL" -o "$PLUGIN_PATH"; then
     echo "  Download successful."
     chmod +x "$PLUGIN_PATH"
     # Add to PATH for this script execution
     export PATH="$PLUGIN_DIR:$PATH"
     echo "✓ lightsailctl downloaded to $PLUGIN_DIR and added to PATH for this session."
     # Add cleanup trap
     # trap "echo 'Cleaning up temporary lightsailctl...'; rm -rf '$PLUGIN_DIR'" EXIT
     return 0
  else
     echo "❌ Download failed. Please install lightsailctl manually." >&2
     rm -rf "$PLUGIN_DIR" # Clean up failed attempt
     return 1
  fi
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

# Domain is initially set from config load/prompt above
echo "👉 Step 1: Check Domain Availability & Confirm Registration/Use Existing"

DOMAIN_OPERATION="register" # Default action is to register a new domain

# Loop until an available domain is confirmed or user quits
while true; do
  echo "Checking availability for '${DOMAIN}'…"
  # Capture stdout and stderr, check exit code
  AVAILABILITY_OUTPUT=$(aws route53domains check-domain-availability \
    --region "$AWS_REGION" \
    --domain-name "$DOMAIN" \
    --query 'Availability' --output text 2>&1) # Capture stderr to stdout
  EXIT_CODE=$?

  # Check if the command was successful and domain is available
  if [[ $EXIT_CODE -eq 0 ]] && [[ "$AVAILABILITY_OUTPUT" == "AVAILABLE" ]]; then
    echo "✅ Domain '${DOMAIN}' is available!"
    read -rp "Use this domain for registration? (y/N): " CONFIRM_DOMAIN
    if [[ "${CONFIRM_DOMAIN,,}" == "y" ]]; then
      echo "✓ Proceeding to register new domain '${DOMAIN}'."
      DOMAIN_OPERATION="register"
      break # Exit the loop, domain confirmed for registration
    else
      echo "Domain registration not confirmed."
      # Fall through to prompt for a new domain
    fi
  else
    # Handle unavailable, unsupported TLD, or other errors
    if [[ $EXIT_CODE -ne 0 ]]; then
      # Extract specific error if possible, otherwise show generic message
      if echo "$AVAILABILITY_OUTPUT" | grep -q "UnsupportedTLD"; then
         echo "❌ The TLD (ending) of '${DOMAIN}' is not supported for registration via AWS."
      elif echo "$AVAILABILITY_OUTPUT" | grep -q "InvalidInput"; then
         echo "❌ Invalid domain name format: '${DOMAIN}'. Please check for typos."
      else
         echo "❌ Error checking domain '${DOMAIN}': $AVAILABILITY_OUTPUT"
      fi
      # Fall through to prompt for a new domain
    else
      # Successful command but domain not available
      echo "ℹ️ Domain '${DOMAIN}' is not available (${AVAILABILITY_OUTPUT}). Checking if registered in this account..."
      # Check if the domain exists in the account's registered domains
      REGISTERED_DOMAINS=$(aws route53domains list-domains --region "$AWS_REGION" --output json 2>&1)
      LIST_EXIT_CODE=$?
      DOMAIN_FOUND_IN_ACCOUNT=false
      if [[ $LIST_EXIT_CODE -eq 0 ]] && echo "$REGISTERED_DOMAINS" | grep -q "\"DomainName\": \"$DOMAIN\""; then
          DOMAIN_FOUND_IN_ACCOUNT=true
      fi

      if [[ "$DOMAIN_FOUND_IN_ACCOUNT" == true ]]; then
          echo "✅ Domain '${DOMAIN}' is already registered in this AWS account."
          read -rp "Use this existing domain registration? (y/N): " CONFIRM_EXISTING
          if [[ "${CONFIRM_EXISTING,,}" == "y" ]]; then
              echo "✓ Proceeding using existing registration for '${DOMAIN}'."
              DOMAIN_OPERATION="use_existing"
              break # Exit the loop, existing domain confirmed
          else
              echo "Existing domain not confirmed for use."
              # Fall through to prompt for a new domain
          fi
      else
          if [[ $LIST_EXIT_CODE -ne 0 ]]; then
              echo "⚠️ Could not list domains in account to verify ownership: $REGISTERED_DOMAINS" >&2
          fi
          echo "❌ Domain '${DOMAIN}' is unavailable and does not appear to be registered in this account."
          # Fall through to prompt for a new domain
      fi
    fi
  fi

  # Prompt for a new domain or quit
  read -rp "Enter a different domain name (or type 'quit' to exit): " NEW_DOMAIN
  if [[ "${NEW_DOMAIN,,}" == "quit" ]]; then
    echo "Exiting script as requested." >&2
    exit 1
  fi
  # Validate new domain input somewhat (basic check for non-empty)
  if [[ -z "$NEW_DOMAIN" ]]; then
      echo "Invalid input. Please enter a domain name or 'quit'." >&2
      continue # Re-prompt without changing DOMAIN
  fi
  DOMAIN="$NEW_DOMAIN"
  # Optionally update the config file here if desired?
  # echo "Updating domain in ${CONFIG_FILE}..."
  # sed -i.bak "s/^DOMAIN=.*/DOMAIN=\"${DOMAIN}\"/" "$CONFIG_FILE"
  # For now, just use the new domain for the current script run

done

# -- Domain is now confirmed and stored in $DOMAIN variable --
# -- DOMAIN_OPERATION indicates whether to 'register' or 'use_existing' --

if [[ "$DOMAIN_OPERATION" == "register" ]]; then
  # Generate register-domain.json using loaded/entered variables
  echo "Generating domain registration request..."
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
  echo "✓ Registration request JSON generated."

  echo "Registering domain ${DOMAIN}…"
  aws route53domains register-domain \
    --region "$AWS_REGION" \
    --cli-input-json file://register-domain.json

  echo "✅ Registration submitted. Track status with:"
  echo "    aws route53domains get-domain-detail --region $AWS_REGION --domain-name $DOMAIN"
  pause
else
  echo "ℹ️ Skipping domain registration step as requested, using existing registration for '${DOMAIN}'."
fi

# ── 2) LIGHTSAIL CONTAINER SERVICE ─────────────────────────────────

echo "👉 Step 2: Create/Confirm Lightsail container service"

# Check if SERVICE_NAME was loaded, otherwise prompt initially
if [[ -z "${SERVICE_NAME:-}" ]]; then
  read -rp "Enter initial Lightsail Service name: " SERVICE_NAME
  # Note: We don't save this back to config automatically, user interaction below handles it.
fi

# Loop until service is successfully created or confirmed
while true; do
  echo "Attempting to create Lightsail container service '${SERVICE_NAME}'..."
  # Temporarily disable exit on error to ensure we capture output/code
  set +e
  CREATE_OUTPUT=$(aws lightsail create-container-service \
    --service-name "$SERVICE_NAME" \
    --power micro \
    --scale 1 2>&1) # Capture stderr
  EXIT_CODE=$?
  # Re-enable exit on error
  set -e

  # --- Debugging --- >
  echo "DEBUG: AWS command exit code: $EXIT_CODE"
  echo "DEBUG: AWS command output: $CREATE_OUTPUT"
  # --- End Debugging ---

  if [[ $EXIT_CODE -eq 0 ]]; then
    echo "✅ Service '${SERVICE_NAME}' created successfully."
    break # Service created, exit loop
  else
    # Check for the specific "already exists" error
    if echo "$CREATE_OUTPUT" | grep -q -E 'Resource.+already exists'; then
      echo "⚠️ Service name '${SERVICE_NAME}' already exists."
      read -rp "(D)elete existing service and recreate, (R)ename service, or (Q)uit? [R]: " SERVICE_ACTION
      SERVICE_ACTION=${SERVICE_ACTION:-R} # Default to Rename

      case "${SERVICE_ACTION,,}" in
        d|delete)
          echo "Attempting to delete existing service '${SERVICE_NAME}'..."
          # Don't exit on error for the delete command itself, check code
          set +e
          DELETE_OUTPUT=$(aws lightsail delete-container-service --service-name "$SERVICE_NAME" 2>&1)
          DELETE_EXIT_CODE=$?
          set -e

          if [[ $DELETE_EXIT_CODE -eq 0 ]]; then
            echo "✓ Delete command issued for service '${SERVICE_NAME}'. Now monitoring deletion status..."
            # --- Monitoring Loop --- >
            MAX_WAIT_SECONDS=300 # Wait up to 5 minutes
            CHECK_INTERVAL_SECONDS=20
            SECONDS_WAITED=0
            DELETED=false
            while [[ $SECONDS_WAITED -lt $MAX_WAIT_SECONDS ]]; do
              echo "  (Waited ${SECONDS_WAITED}s / ${MAX_WAIT_SECONDS}s) Checking if service '${SERVICE_NAME}' is deleted..."
              set +e # Don't exit if get-container-service fails (means it's deleted)
              aws lightsail get-container-service --service-name "$SERVICE_NAME" > /dev/null 2>&1
              GET_EXIT_CODE=$?
              set -e

              if [[ $GET_EXIT_CODE -ne 0 ]]; then
                # Command failed, likely because the service is gone
                echo "✓ Service '${SERVICE_NAME}' appears to be deleted."
                DELETED=true
                break
              fi
              # If command succeeded, service still exists (likely DELETING)
              echo "  Service still exists. Waiting ${CHECK_INTERVAL_SECONDS}s before checking again..."
              sleep $CHECK_INTERVAL_SECONDS
              SECONDS_WAITED=$((SECONDS_WAITED + CHECK_INTERVAL_SECONDS))
            done
            # --- End Monitoring Loop ---

            if [[ "$DELETED" == true ]]; then
              echo "✓ Deletion confirmed. Proceeding to recreate service."
              continue # Loop back to the outer loop to try creating again
            else
              echo "❌ Service '${SERVICE_NAME}' was not confirmed deleted after ${MAX_WAIT_SECONDS} seconds." >&2
              echo "Please check the AWS Lightsail console manually." >&2
              # Fall through to prompt for rename/quit after timeout
            fi

          else
            echo "❌ Failed to issue delete command for service '${SERVICE_NAME}': $DELETE_OUTPUT" >&2
            # Fall through to prompt for rename/quit if delete failed
          fi

          # --- Fallthrough for failed delete or timeout ---
          echo "Cannot proceed with deletion/recreation." >&2
          read -rp "(R)ename service, or (Q)uit? [R]: " RENAME_QUIT_ACTION
          RENAME_QUIT_ACTION=${RENAME_QUIT_ACTION:-R}
          if [[ "${RENAME_QUIT_ACTION,,}" == "q" ]]; then
             echo "Exiting script." >&2; exit 1;
          fi
          # Intentional fallthrough to rename logic below if R is chosen
          ;;
        q|quit)
          echo "Exiting script as requested." >&2
          exit 1
          ;;
        r|rename|*)
          # Default to rename or if 'r' is chosen explicitly
          read -rp "Enter a *different* Lightsail Service name: " NEW_SERVICE_NAME
          if [[ -z "$NEW_SERVICE_NAME" || "$NEW_SERVICE_NAME" == "$SERVICE_NAME" ]]; then
              echo "Invalid or unchanged name. Please enter a different name." >&2
              continue # Re-prompt within the error handling
          fi
          SERVICE_NAME="$NEW_SERVICE_NAME"
          echo "✓ Changed service name to '${SERVICE_NAME}'. Retrying creation..."
          continue # Loop back to try creating with the new name
          ;;
      esac
    else
      # Handle other errors during creation
      echo "❌ An unexpected error occurred creating service '${SERVICE_NAME}': $CREATE_OUTPUT" >&2
      exit 1 # Exit on unexpected errors
    fi
  fi
done

# --- Service $SERVICE_NAME is now created/confirmed ---

pause

# Ensure lightsailctl is available before proceeding to push
echo ""
echo "👉 Checking for Lightsail Control plugin (lightsailctl)..."
ensure_lightsailctl || { echo "❌ Failed to ensure lightsailctl is available. Exiting." >&2; exit 1; }

# ── 3) BUILD & PUSH DOCKER IMAGE ───────────────────────────────────

echo ""
echo "👉 Step 3: Build & push Docker image"
# Use the SERVICE_NAME obtained above
docker build -t "$SERVICE_NAME:latest" .
aws lightsail push-container-image \
  --region "$AWS_REGION" \
  --service-name "$SERVICE_NAME" \
  --label app \
  --image "$SERVICE_NAME:latest"

pause

# ── 4) DEPLOY TO LIGHTSAIL ─────────────────────────────────────────

echo "👉 Step 4: Deploy container"
# Use the SERVICE_NAME obtained above
# Ensure the image label reflects the actual pushed image tag, typically .1, .2 etc.
# Get the latest pushed image URI
LATEST_IMAGE_URI=$(aws lightsail get-container-images --service-name "$SERVICE_NAME" --query 'containerImages[0].image' --output text)
if [[ -z "$LATEST_IMAGE_URI" ]]; then
  echo "❌ Could not determine the latest pushed image URI for service $SERVICE_NAME. Deployment might fail."
  # Fallback to default format, but this is less reliable
  LATEST_IMAGE_URI=":$SERVICE_NAME.app.1" # This was the original assumption, might be wrong
else
  echo "ℹ️ Using image URI for deployment: $LATEST_IMAGE_URI"
fi

cat > deploy.json <<EOF
{
  "serviceName": "$SERVICE_NAME",
  "containers": {
    "app": {
      "image": "${LATEST_IMAGE_URI}",
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
# Use DOMAIN and SERVICE_NAME obtained above
aws lightsail create-domain-entry \
  --domain-name "$DOMAIN" \
  --domain-entry name="$DOMAIN",target="$(aws lightsail get-container-service \
    --service-name "$SERVICE_NAME" \
    --region "$AWS_REGION" \
    --query 'containerService.publicDomainName' \
    --output text)",type=A,isAlias=true

echo "🎉 Done! Allow DNS 10–30 minutes, then visit: https://${DOMAIN}"

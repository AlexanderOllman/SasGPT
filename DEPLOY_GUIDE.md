# Guide: Using the aws-deploy.sh Script

This guide explains how to generate the necessary AWS credentials and run the `aws-deploy.sh` script to deploy the application to AWS Lightsail with a custom domain registered via Route 53.

## Prerequisites

1.  **Docker:** The script uses Docker to build the application container. Ensure Docker is installed and the Docker daemon is running.
2.  **Bash Shell:** The script is written for bash.
3.  **`curl` and `unzip`:** These utilities are used by the script to potentially download and install the AWS CLI. Make sure they are installed.
4.  **(Linux ARM64 Only) `python3` and `pip`:** If you are running on a Linux ARM64 machine, the script might fall back to installing the AWS CLI v1 using pip.

## Step 1: Generate AWS Credentials

The script requires AWS credentials with permissions to manage Route 53 Domains and Lightsail. Follow these steps to create dedicated credentials:

1.  **Log in to the AWS Management Console:** Use your existing AWS account.
2.  **Navigate to IAM:** Search for "IAM" in the AWS services search bar and go to the IAM dashboard.
3.  **Create an IAM User:**
    *   In the IAM dashboard, click on "Users" in the left-hand navigation pane.
    *   Click the "Create user" button.
    *   Enter a **User name** (e.g., `sasgpt-lightsail-deployer`).
    *   Click **Next**.
4.  **Set Permissions:**
    *   Choose **Attach policies directly**.
    *   Click **Create policy**. This will open a new browser tab.
        *   In the new tab, select the **JSON** tab.
        *   Delete the placeholder content and paste the following JSON policy definition. This grants full access to Lightsail, Route 53 Domains, and standard Route 53 actions (needed for hosted zone creation):
          ```json
          {
              "Version": "2012-10-17",
              "Statement": [
                  {
                      "Effect": "Allow",
                      "Action": [
                          "lightsail:*"
                      ],
                      "Resource": "*"
                  },
                  {
                      "Effect": "Allow",
                      "Action": [
                          "route53domains:*"
                      ],
                      "Resource": "*"
                  },
                  {
                      "Effect": "Allow",
                      "Action": [
                          "route53:*"
                      ],
                      "Resource": "*"
                  }
              ]
          }
          ```
        *   Click **Next: Tags** (adding tags is optional).
        *   Click **Next: Review**.
        *   Enter a **Name** for the policy (e.g., `LightsailRoute53AndDomainsFullAccessCustom`).
        *   (Optional) Add a description.
        *   Click **Create policy**.
        *   Close this browser tab and return to the original "Create user" tab.
    *   Back in the "Create user" tab, click the refresh button next to the "Create policy" button.
    *   In the filter policies search box, search for the policy you just created (e.g., `LightsailRoute53AndDomainsFullAccessCustom`) and select it.
    *   *(Optional Security Note: For production environments, it's recommended to create a custom IAM policy with only the specific permissions required by the script instead of using these broad full-access policies.)*
    *   Click **Next**.
5.  **Review and Create:**
    *   Review the user details and attached policies.
    *   Click **Create user**.
6.  **Retrieve Access Keys:**
    *   After the user is created, click on the username in the user list.
    *   Go to the **Security credentials** tab.
    *   Scroll down to the **Access keys** section and click **Create access key**.
    *   Select **Command Line Interface (CLI)** as the use case.
    *   Acknowledge the recommendation regarding alternatives (for this script, we need the keys).
    *   Click **Next**.
    *   (Optional) Set a description tag (e.g., `lightsail-deploy-script-key`).
    *   Click **Create access key**.
7.  ** VERY IMPORTANT: Securely Store Keys:**
    *   The **Access key ID** and **Secret access key** will be displayed.
    *   **Copy both the Access key ID and the Secret access key immediately and store them in a secure location (like a password manager).** The Secret access key will **not** be shown again after you leave this screen.
    *   You can also download the keys as a `.csv` file.
    *   **Never commit these keys to your Git repository or share them publicly.**

## Step 2: Run the Deployment Script

1.  **Navigate to Project Directory:** Open your terminal or command prompt and change to the directory containing the `aws-deploy.sh` script and the rest of the project files.
2.  **Execute the Script:** Run the script using bash:
    ```bash
    bash aws-deploy.sh
    ```
3.  **Enter AWS Credentials:** The script will first prompt you for the AWS credentials you just generated:
    *   `Enter AWS Access Key ID:` (Paste the Access Key ID)
    *   `Enter AWS Secret Access Key:` (Paste the Secret Access Key - it won't be visible as you type)
    *   `Enter AWS Session Token (optional, press ENTER if none):` (Press Enter unless you are using temporary credentials that include a session token)
    *   `Enter AWS Region [us-east-1]:` (Press Enter to use the default `us-east-1`, or type a different region code)
4.  **Follow Prompts:** The script will then guide you through the rest of the process, asking for:
    *   Domain registration details (domain name, duration, contact info).
        *   **Important Phone Format:** Ensure the phone number is entered in the format `+<country_code>.<number>` (e.g., `+1.5551234567`).
    *   Confirmation of domain availability.
    *   A service name for the Lightsail container service.
5.  **Press Enter to Continue:** The script includes several `pause` points after initiating major AWS operations (like domain registration, service creation, image push, deployment). Simply press `ENTER` at these prompts to proceed to the next step.

## Post-Deployment

*   **DNS Propagation:** After the script completes, it might take 10-30 minutes (or sometimes longer) for the DNS changes to propagate globally. Once propagated, you should be able to access your application at `https://<your-domain.com>`.
*   **Check AWS Console:** You can monitor the status of the domain registration in the Route 53 console and the container service/deployment in the Lightsail console.
*   **Cleanup:** The script creates temporary files (`register-domain.json`, `deploy.json`). You can safely delete these after the script finishes successfully. Consider deleting the generated IAM user and access keys if this deployment was temporary or for testing purposes. 
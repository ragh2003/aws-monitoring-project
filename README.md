# AWS Security Monitoring System

This project implements an AWS security monitoring system to detect unauthorized access to Secrets Manager secrets using Terraform for infrastructure provisioning and Boto3 for automation. It leverages CloudTrail for logging, CloudWatch for metrics and alarms, and SNS for email notifications. The system was built following the NextWork YouTube tutorial as part of AWS/DevOps interview preparation, showcasing infrastructure as code, automation, and monitoring skills.

## Project Overview

The system creates a secret in AWS Secrets Manager, logs access attempts via CloudTrail, converts logs to metrics in CloudWatch, and triggers email alerts via SNS when the secret is accessed. A Python script using Boto3 simulates secret access to test the monitoring pipeline. The **Secret Mission** involved setting up CloudWatch-SNS notifications (successful) and troubleshooting an unsuccessful CloudTrail-SNS direct notification setup.

### Technologies Used
- **Terraform**: Provisions AWS resources (Secrets Manager, CloudTrail, S3, CloudWatch, SNS, IAM).
- **Boto3**: Automates secret access with Python.
- **AWS CloudTrail**: Logs `GetSecretValue` API calls to an S3 bucket and CloudWatch Logs.
- **AWS CloudWatch**: Filters logs into metrics (`SecretIsAccessed`) and triggers alarms (`secret-was-accessed`).
- **AWS SNS**: Sends email notifications for CloudWatch alarms to `kampai1573@gmail.com`.
- **Git/GitHub**: Version control and portfolio hosting (`https://github.com/ragh2003/aws-monitoring-project`).

### Key Features
- **Secrets Manager**: Stores a test secret (`top-secret-info-<suffix>`) with a random suffix for uniqueness.
- **CloudTrail**: Captures `GetSecretValue` events, storing logs in an S3 bucket (`secrets-manager-trail-<suffix>`) and CloudWatch Logs (`/aws/cloudtrail/secrets-manager-log-group`).
- **CloudWatch**: 
  - Metric filter (`get-secrets-value`) extracts `GetSecretValue` events.
  - Metric (`SecretIsAccessed`) tracks access attempts.
  - Alarm (`secret-was-accessed`) triggers on access, sending SNS notifications.
- **SNS**: Delivers clean, production-ready email alerts via CloudWatch-SNS when the secret is accessed.
- **Boto3 Script**: Simulates two `GetSecretValue` calls to trigger monitoring.
- **Secret Mission**: Successfully implemented CloudWatch-SNS notifications (clean, delayed alerts); CloudTrail-SNS (direct, verbose) was attempted but not successful due to configuration issues.

## Prerequisites
- **AWS Account**: Configured with an IAM user (`monitoring-project-user`) with `AdministratorAccess`.
- **Tools**:
  - Terraform (v1.5+)
  - Python (3.8+)
  - Boto3 (`pip install boto3`)
  - AWS CLI (configured with credentials)
  - Git
- **GitHub**: Repository at `https://github.com/ragh2003/aws-monitoring-project`.

## Setup Instructions
1. **Clone the Repository**:
   ```
   git clone https://github.com/ragh2003/aws-monitoring-project.git
   cd aws-monitoring-project
   ```
2. **Set Up Python Environment**:
   ```
   python -m venv venv
   .\venv\Scripts\activate  # Windows
   pip install boto3
   ```
3. **Configure AWS CLI**:
   - Run `aws configure` and enter credentials for `monitoring-project-user` (access key, secret key, region: `us-east-1`).
4. **Initialize Terraform**:
   ```
   terraform init
   ```
5. **Apply Terraform Configuration**:
   ```
   terraform plan -out=tfplan
   terraform apply tfplan
   ```
   - Type `yes`.
   - Takes ~5-10 minutes.
   - Outputs `secret_name` (e.g., `top-secret-info-xjgryx5m`).
6. **Confirm SNS Subscription**:
   - Check `kampai1573@gmail.com` (inbox/spam) for SNS confirmation link for `security-alarms-<suffix>`.
   - Click to confirm subscription.
7. **Update Boto3 Script**:
   - Edit `access_secret.py`, set `SECRET_NAME` to `terraform output secret_name`.
8. **Run Boto3 Script**:
   ```
   python access_secret.py
   ```
   - Expected output:
     ```
     INFO:__main__:Access attempt 1
     INFO:__main__:Attempting to retrieve secret: top-secret-info-xjgryx5m
     INFO:__main__:Secret retrieved successfully: I need three coffees a day to function
     INFO:__main__:Access attempt 2
     INFO:__main__:Attempting to retrieve secret: top-secret-info-xjgryx5m
     INFO:__main__:Secret retrieved successfully: I need three coffees a day to function
     ```
9. **Verify Monitoring**:
   - **CloudTrail**: Check `GetSecretValue` events in Console > CloudTrail > Event history (~5-15 minute delay).
   - **CloudWatch Logs**: Run in Console > CloudWatch > Logs Insights:
     ```
     fields @timestamp, eventName, eventSource
     | filter eventName = "GetSecretValue" and eventSource = "secretsmanager.amazonaws.com"
     | sort @timestamp desc
     ```
   - **CloudWatch Metrics**: Check `SecurityMetrics/SecretIsAccessed` (value >= 1).
   - **CloudWatch Alarm**: Verify `secret-was-accessed` is “In Alarm”.
   - **SNS Email**: Check `kampai1573@gmail.com` for CloudWatch-SNS alert (~2-5 minute delay).
10. **Clean Up**:
    ```
    terraform destroy
    ```
    - Type `yes`.
    - Delete SNS subscription (Console > SNS > Subscriptions).

## Secret Mission: CloudWatch-SNS vs. CloudTrail-SNS
- **Objective**: Compare CloudTrail-SNS (direct, verbose notifications) vs. CloudWatch-SNS (filtered, delayed notifications).
- **CloudWatch-SNS**:
  - **Status**: Successful.
  - **Description**: Uses a metric filter to detect `GetSecretValue` events, updates `SecretIsAccessed` metric, and triggers `secret-was-accessed` alarm, sending clean SNS email notifications (e.g., “Alarm secret-was-accessed in us-east-1”).
  - **Pros**: Polished, production-ready, filters noise for clear alerts.
  - **Cons**: Delayed (~1-2 minutes) due to metric processing.
- **CloudTrail-SNS**:
  - **Status**: Unsuccessful.
  - **Description**: Attempted to send raw `GetSecretValue` events directly to SNS via a CloudWatch Events rule (`cloudtrail-direct-sns`). Failed due to configuration issues (e.g., event pattern or SNS topic policy).
  - **Intended Pros**: Fast, immediate notifications with full event details.
  - **Intended Cons**: Verbose JSON output, less user-friendly.
- **Observation**: CloudWatch-SNS is better for production due to its clean, filtered alerts, despite the delay. CloudTrail-SNS, if successful, would suit real-time debugging but is too noisy for regular use.

## Project Structure
```
aws-monitoring-project/
├── main.tf               # Terraform configuration for AWS resources
├── access_secret.py      # Boto3 script to access secret and trigger alerts
├── .gitignore            # Ignores Terraform state, credentials, and venv
├── README.md             # Project documentation
├── screenshots/          # Screenshots of outputs and alerts
│   ├── terraform-apply.png
│   ├── boto3-output.png
│   ├── cloudwatch-alarm.png
│   ├── sns-email.png
```

## Screenshots
- **Terraform Apply Output**: Shows successful resource creation and `secret_name`.
- **Boto3 Script Output**: Displays two successful `GetSecretValue` calls.
- **CloudWatch Alarm**: `secret-was-accessed` in “In Alarm” state.
- **SNS Email**: CloudWatch-SNS notification for secret access.

## Learnings
- **Terraform**: Mastered provisioning Secrets Manager, CloudTrail, S3, CloudWatch, SNS, and IAM resources.
- **Boto3**: Automated secret access and handled AWS API errors (e.g., `AccessDenied`).
- **CloudWatch**: Configured metric filters, metrics, and alarms for monitoring.
- **SNS**: Set up email subscriptions and troubleshot confirmation issues.
- **Git/GitHub**: Resolved authentication issues (PAT setup) and pushed commits to `https://github.com/ragh2003/aws-monitoring-project`.
- **Troubleshooting**:
  - Fixed Terraform errors (S3 bucket policy, CloudWatch alarm attributes).
  - Updated IAM permissions for `monitoring-project-user`.
  - Addressed Git push errors (e.g., `origin/main` syntax, PAT authentication).
  - Debugged missing CloudTrail-SNS notifications (unsuccessful).

## Troubleshooting Tips
- **Terraform Apply Fails**:
  - Ensure IAM user (`monitoring-project-user`) has `AdministratorAccess`.
  - Check `main.tf` syntax and region (`us-east-1`).
- **Boto3 Errors**:
  - **AccessDenied**: Add IAM policy:
    ```json
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": "secretsmanager:GetSecretValue",
          "Resource": "arn:aws:secretsmanager:us-east-1:852567287225:secret:top-secret-info-*"
        }
      ]
    }
    ```
  - **ResourceNotFound**: Verify `SECRET_NAME` matches `terraform output secret_name`.
- **No SNS Email**:
  - Confirm subscription in Console > SNS > Subscriptions.
  - Resubscribe:
    ```
    aws sns subscribe --topic-arn arn:aws:sns:us-east-1:852567287225:security-alarms-<suffix> --protocol email --notification-endpoint kampai1573@gmail.com
    ```
  - Check inbox/spam and wait ~5-15 minutes.
- **GitHub Push Fails**:
  - Verify PAT (repo scope) and username (`ragh2003`).
  - Update Windows Credential Manager.
  - Use correct command: `git push origin main`.

## Future Improvements
- Fix CloudTrail-SNS notifications by debugging `cloudtrail-direct-sns` event rule and SNS topic policy.
- Add error handling in `access_secret.py` for rate limiting.
- Enhance `README.md` with architecture diagram.
- Implement multi-region CloudTrail for broader coverage.

## References
- NextWork YouTube tutorial (AWS security monitoring).
- AWS Documentation: Secrets Manager, CloudTrail, CloudWatch, SNS, Terraform, Boto3.
- GitHub: `https://github.com/ragh2003/aws-monitoring-project`.
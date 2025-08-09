import boto3
import json
import time
import logging

# starting to set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def get_secret(secret_name, region='us-east-1'):
    """Retrieve secret from AWS Secrets Manager."""
    try:
        client = boto3.client('secretsmanager', region_name=region)
        logger.info(f"Attempting to retrieve secret: {secret_name}")
        response = client.get_secret_value(SecretId=secret_name)
        secret = json.loads(response['SecretString'])
        logger.info(f"Secret retrieved successfully: {secret['secret']}")
        return secret
    except client.exceptions.ClientError as e:
        logger.error(f"Failed to retrieve secret: {e}")
        raise

if __name__ == "__main__":
    SECRET_NAME = "top-secret-info-xm9xlg77"  # terraform output which came after running the trraform apply command
    REGION = "us-east-1"

    for i in range(2):
        logger.info(f"Access attempt {i+1}")
        get_secret(SECRET_NAME, REGION)
        time.sleep(10)
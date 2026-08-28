import logging
import os
import urllib.parse

import boto3


logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")

PRIVATE_BUCKET = os.environ["PRIVATE_BUCKET"]


def lambda_handler(event, context):
    logger.info("Received event")

    for record in event.get("Records", []):
        source_bucket = record["s3"]["bucket"]["name"]
        source_key = urllib.parse.unquote_plus(
            record["s3"]["object"]["key"],
            encoding="utf-8",
        )

        if not source_key.startswith("mysql/"):
            logger.info(
                "Ignoring object outside mysql/ prefix: %s",
                source_key,
            )
            continue

        destination_key = source_key

        logger.info(
            "Copying s3://%s/%s to s3://%s/%s",
            source_bucket,
            source_key,
            PRIVATE_BUCKET,
            destination_key,
        )

        s3.copy_object(
            Bucket=PRIVATE_BUCKET,
            CopySource={
                "Bucket": source_bucket,
                "Key": source_key,
            },
            Key=destination_key,
        )

        logger.info(
            "Successfully copied s3://%s/%s to s3://%s/%s",
            source_bucket,
            source_key,
            PRIVATE_BUCKET,
            destination_key,
        )

    return {
        "statusCode": 200,
        "message": "Backup copy completed",
    }

#!/bin/bash

if [[ "$#" -lt 1 || "$1" = "--help" ]]; then
	echo "Syntax: $0 S3_NAME AWS_REGION"
	echo ""
	echo "Create S3 bucket and the related secret to use with Thanos"
	echo "You need to have the AWS CLI installed and configured."
	echo ""
	echo "  e.g: $0 yourname-thanos eu-west-1"
	echo ""
	exit
fi

export YOUR_S3_BUCKET="$1"
export YOUR_S3_REGION="$2"
export YOUR_ACCESS_KEY=$(aws configure get aws_access_key_id)
export YOUR_SECRET_KEY=$(aws configure get aws_secret_access_key)
export YOUR_S3_ENDPOINT="s3.${YOUR_S3_REGION}.amazonaws.com"

aws s3api create-bucket --bucket $YOUR_S3_BUCKET  --region $YOUR_S3_REGION --create-bucket-configuration LocationConstraint=$YOUR_S3_REGION

curl -s -L "https://raw.githubusercontent.com/netobserv/netobserv-documents/main/blogs/acm/thanos-secret.yaml" | envsubst | kubectl apply -f -
# cat thanos-secret.yaml | envsubst | kubectl apply -f -

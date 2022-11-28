#!/bin/bash

if [[ "$#" -lt 1 || "$1" = "--help" ]]; then
	echo "Syntax: $0 S3_NAME AWS_REGION"
	echo ""
	echo "Create S3 bucket and the related secret to use with the Loki operator"
	echo "You need to have the AWS CLI installed and configured."
	echo ""
	echo "  e.g: $0 yourname-loki eu-west-1"
	echo ""
	exit
fi

S3_NAME="$1"
AWS_REGION="$2"
AWS_KEY=$(aws configure get aws_access_key_id)
AWS_SECRET=$(aws configure get aws_secret_access_key)

aws s3api create-bucket --bucket $S3_NAME  --region $AWS_REGION --create-bucket-configuration LocationConstraint=$AWS_REGION

SECRET=lokistack-dev-s3
NAMESPACE=netobserv

kubectl create namespace $NAMESPACE
kubectl create -n $NAMESPACE secret generic ${SECRET} \
  --from-literal=bucketnames="$S3_NAME" \
  --from-literal=endpoint="https://s3.${AWS_REGION}.amazonaws.com" \
  --from-literal=access_key_id="${AWS_KEY}" \
  --from-literal=access_key_secret="${AWS_SECRET}" \
  --from-literal=region="${AWS_REGION}"

kubectl apply -n $NAMESPACE -f examples/loki-stack/demo-hack.yaml
kubectl apply -n $NAMESPACE -f examples/loki-stack/role-hack.yaml

echo ""
echo "⏳ Waiting for LokiStack being ready..."

kubectl wait --timeout=180s --for=condition=ready lokistack loki -n $NAMESPACE

echo ""
echo "Deployment complete"
echo ""
echo "Configure FlowCollector Loki with:"
echo "    url: 'https://loki-gateway-http.${NAMESPACE}.svc:8080/api/logs/v1/infrastructure/'"
echo "    statusUrl: 'https://loki-query-frontend-http.${NAMESPACE}.svc:3100/'"
echo "    tenantID: infrastructure"
echo "    authToken: HOST"
echo "    tls:"
echo "      enable: true"
echo "      caCert:"
echo "        type: configmap"
echo "        name: loki-ca-bundle"
echo "        certFile: service-ca.crt"
echo ""
echo "To delete all created Kube resources, run:"
echo "kubectl delete -n $NAMESPACE secret $SECRET"
echo "kubectl delete -n $NAMESPACE -f examples/loki-stack/demo.yaml"
echo "kubectl delete -f examples/loki-stack/role.yaml"
echo ""
echo "To delete the S3 bucket, run:"
echo "aws s3 rm s3://$S3_NAME --recursive"
echo "aws s3 rb s3://$S3_NAME"

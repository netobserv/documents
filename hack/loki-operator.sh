#!/bin/bash

if [[ "$#" -lt 1 || "$1" = "--help" ]]; then
	echo "Syntax: $0 S3_NAME AWS_REGION NAMESPACE"
	echo ""
	echo "Create S3 bucket and the related secret to use with the Loki operator"
	echo "You need to have the AWS CLI installed and configured."
	echo ""
	echo "  e.g: $0 yourname-loki eu-west-1 loki"
	echo ""
	exit
fi

S3_NAME="$1"
AWS_REGION="$2"
NAMESPACE="netobserv"
if [[ "$3" != "" ]]; then
	NAMESPACE="$3"
fi

AWS_KEY=$(aws configure get aws_access_key_id)
AWS_SECRET=$(aws configure get aws_secret_access_key)

aws s3api create-bucket --bucket $S3_NAME  --region $AWS_REGION --create-bucket-configuration LocationConstraint=$AWS_REGION

SECRET=lokistack-dev-s3

kubectl create namespace $NAMESPACE
kubectl create -n $NAMESPACE secret generic ${SECRET} \
  --from-literal=bucketnames="$S3_NAME" \
  --from-literal=endpoint="https://s3.${AWS_REGION}.amazonaws.com" \
  --from-literal=access_key_id="${AWS_KEY}" \
  --from-literal=access_key_secret="${AWS_SECRET}" \
  --from-literal=region="${AWS_REGION}"

kubectl apply -n $NAMESPACE -f examples/loki-stack/demo.yaml

echo ""
echo "Deployment complete"
echo ""
echo "Configure FlowCollector Loki with:"
echo "    mode: LokiStack"
echo "    lokiStack:"
echo "      name: loki"
echo "      namespace: $NAMESPACE"
echo ""
echo "To allow test user reading flow logs, run:"
echo "kubectl apply -n $NAMESPACE -f examples/loki-stack/rolebinding-user-test.yaml"
echo "or"
echo "oc adm policy add-cluster-role-to-user netobserv-loki-reader test"
echo ""
echo "To delete all created Kube resources, run:"
echo "kubectl delete -n $NAMESPACE secret $SECRET"
echo "kubectl delete -n $NAMESPACE -f examples/loki-stack/demo.yaml"
echo "kubectl delete -n $NAMESPACE pvc --all"
echo ""
echo "To delete the S3 bucket, run:"
echo "aws s3 rm s3://$S3_NAME --recursive"
echo "aws s3 rb s3://$S3_NAME"


echo ""
echo "⏳ Waiting for LokiStack to be ready..."

kubectl wait --timeout=180s --for=condition=ready lokistack loki -n $NAMESPACE

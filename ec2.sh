#!/bin/bash

# Set variables
INSTANCE_TYPE="t2.micro"
AMI_ID="ami-12345678"  # Replace with a valid AMI ID
KEY_NAME="my-key-pair"  # Replace with your key pair name
SECURITY_GROUP="sg-12345678"  # Replace with your security group

echo "Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME --security-group-ids $SECURITY_GROUP --query "Instances[0].InstanceId" --output text)

echo "Instance ID: $INSTANCE_ID"

# Function to check CPU utilization
check_activity() {
  CPU_UTIL=$(aws cloudwatch get-metric-statistics --namespace AWS/EC2 --metric-name CPUUtilization \
    --dimensions Name=InstanceId,Value=$INSTANCE_ID --statistics Average --period 3600 --start-time $(date -u -d '2 hours ago' +"%Y-%m-%dT%H:%M:%SZ") \
    --end-time $(date -u +"%Y-%m-%dT%H:%M:%SZ") --query "Datapoints[*].Average" --output text)
  
  if [[ -z "$CPU_UTIL" || $(echo "$CPU_UTIL < 1.0" | bc) -eq 1 ]]; then
    echo "No activity detected in the last two hours. Terminating instance..."
    aws ec2 terminate-instances --instance-ids $INSTANCE_ID
  else
    echo "Instance is active."
  fi
}

# Wait for instance to initialize
sleep 60
echo "Monitoring instance activity..."

# Check every 30 minutes
while true; do
  check_activity
  sleep 1800
done

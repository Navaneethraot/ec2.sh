#!/bin/bash

# Set variables
INSTANCE_TYPE="t2.micro"
AMI_ID="ami-00a929b66ed6e0de6"
KEY_NAME="test"  
SECURITY_GROUP="sg-0e7071125a50388dd" 
TAG_NAME="AutoTerminateInstance"

#!/bin/bash

# Create EC2 instance
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-groups $SECURITY_GROUP \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$TAG_NAME}]" \
    --query "Instances[0].InstanceId" --output text)

echo "Instance $INSTANCE_ID created. Waiting for it to be running..."

# Wait for instance to be in running state
aws ec2 wait instance-running --instance-ids $INSTANCE_ID
echo "Instance $INSTANCE_ID is now running."

# Get Public IP
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[0].Instances[0].PublicIpAddress" --output text)
echo "Public IP: $PUBLIC_IP"

# Install Docker, Node.js, and Git on the instance
ssh -o StrictHostKeyChecking=no -i $KEY_NAME.pem ec2-user@$PUBLIC_IP << 'EOF'
sudo yum update -y
sudo yum install -y docker git
curl -sL https://rpm.nodesource.com/setup_16.x | sudo bash -
sudo yum install -y nodejs
sudo systemctl start docker
sudo systemctl enable docker
echo "Installation complete."
EOF

# Background process to terminate instance if inactive for 2 hours
nohup ssh -o StrictHostKeyChecking=no -i $KEY_NAME.pem ec2-user@$PUBLIC_IP << 'EOF' &
while true; do
    LAST_ACTIVITY=$(who -b | awk '{print $3, $4}')
    LAST_ACTIVITY_TIMESTAMP=$(date -d "$LAST_ACTIVITY" +%s)
    CURRENT_TIMESTAMP=$(date +%s)
    IDLE_TIME=$((CURRENT_TIMESTAMP - LAST_ACTIVITY_TIMESTAMP))
    if [ "$IDLE_TIME" -ge 7200 ]; then
        echo "No activity detected for 2 hours. Terminating instance..."
        aws ec2 terminate-instances --instance-ids $INSTANCE_ID
        break
    fi
    sleep 600
done
EOF

echo "Background process initiated to monitor inactivity."


#!/bin/bash

# Set variables
INSTANCE_TYPE="t2.micro"
AMI_ID="ami-00a929b66ed6e0de6"
KEY_NAME="test"  
SECURITY_GROUP_ID="sg-0e7071125a50388dd" 
TAG_NAME="AutoTerminateInstance"


# Create User Data for installing Docker, Node.js, and Git
cat <<EOF > userdata.sh
#!/bin/bash
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker

# Install Git
yum install -y git

# Install Node.js (Latest LTS)
curl -sL https://rpm.nodesource.com/setup_lts.x | bash -
yum install -y nodejs

# Add ec2-user to docker group
usermod -aG docker ec2-user

# Save Installed Versions
docker --version > /tmp/installed_versions.txt
git --version >> /tmp/installed_versions.txt
node --version >> /tmp/installed_versions.txt
npm --version >> /tmp/installed_versions.txt

echo "Setup Completed Successfully" >> /tmp/setup.log
EOF

echo "Launching EC2 Instance..."

# Launch EC2 Instance
INSTANCE_ID=$(aws ec2 run-instances \
--image-id $AMI_ID \
--instance-type $INSTANCE_TYPE \
--key-name $KEY_NAME \
--security-group-ids $SECURITY_GROUP_ID \
--subnet-id $SUBNET_ID \
--user-data file://userdata.sh \
--tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$TAG_NAME}]" \
--query "Instances[0].InstanceId" \
--output text)

echo "Instance ID: $INSTANCE_ID"

echo "Waiting for instance to be in running state..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

echo "Instance is now running."

# Get Public IP
PUBLIC_IP=$(aws ec2 describe-instances \
--instance-ids $INSTANCE_ID \
--query "Reservations[0].Instances[0].PublicIpAddress" \
--output text)

echo "Public IP: $PUBLIC_IP"

echo "You can SSH using: ssh -i $KEY_NAME.pem ec2-user@$PUBLIC_IP"

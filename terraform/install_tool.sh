#!/bin/bash
# Update packages
apt-get update -y
apt-get upgrade -y

# Install basic tools
apt-get install -y git jq curl wget vim unzip tar gzip openjdk-11-jdk

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip /tmp/awscliv2.zip -d /tmp
/tmp/aws/install

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
mv /tmp/eksctl /usr/local/bin/

# Install Jenkins
wget -O /etc/apt/trusted.gpg.d/jenkins.asc https://pkg.jenkins.io/debian/jenkins.io.key
sh -c 'echo deb https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
apt-get update -y
apt-get install -y jenkins
systemctl enable jenkins
systemctl start jenkins

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu   # Add default user to docker group
systemctl enable docker
systemctl start docker

# Verify installations
kubectl version --client
helm version
eksctl version
aws --version
java -version
jenkins --version
docker --version


# Troubleshooting Guide - EKS Terraform Infrastructure

This guide covers common issues and their solutions when deploying EKS infrastructure with Terraform and GitHub Actions.

## 🚨 Common Issues and Solutions

### 1. GitHub Actions Authentication Issues

#### Problem: "Unable to assume role"
```
Error: failed to assume IAM role: failed to get credentials for assume role: error calling AssumeRoleWithWebIdentity
```

**Solutions:**

1. **Verify OIDC Provider:**
   ```bash
   aws iam list-open-id-connect-providers
   ```
   Should show: `https://token.actions.githubusercontent.com`

2. **Check Trust Policy:**
   ```bash
   aws iam get-role --role-name GitHubActions-TerraformRole
   ```
   Verify the trust policy includes your repository path.

3. **Verify GitHub Repository Settings:**
   - Ensure `AWS_ROLE_TO_ASSUME` secret is correctly set
   - Check repository name matches the trust policy

#### Problem: "Permission denied" errors
**Solutions:**

1. **Check IAM Policy:**
   ```bash
   aws iam list-attached-role-policies --role-name GitHubActions-TerraformRole
   ```

2. **Add missing permissions:**
   The role needs permissions for all AWS services used by Terraform.

### 2. Terraform State Issues

#### Problem: "State file locked"
```
Error: Error acquiring the state lock: ConditionalCheckFailedException
```

**Solutions:**

1. **Check if another workflow is running:**
   - Look for concurrent GitHub Actions workflows
   - Wait for other runs to complete

2. **Force unlock (use carefully!):**
   ```bash
   terraform force-unlock <lock-id>
   ```

3. **Verify DynamoDB table:**
   ```bash
   aws dynamodb describe-table --table-name terraform-state-lock-dev
   ```

#### Problem: "Backend configuration not found"
```
Error: Backend configuration changed
```

**Solutions:**

1. **Re-initialize with correct backend:**
   ```bash
   terraform init -backend-config="environments/dev/backend.conf" -reconfigure
   ```

2. **Verify S3 bucket exists:**
   ```bash
   aws s3 ls s3://your-terraform-state-bucket
   ```

### 3. EKS Cluster Issues

#### Problem: "Cluster creation timeout"
```
Error: waiting for EKS Cluster (cluster-name) create: timeout while waiting for state to become 'ACTIVE'
```

**Solutions:**

1. **Check AWS Service Health:**
   - Verify EKS service is available in your region
   - Check AWS Status page

2. **Verify Subnet Configuration:**
   ```bash
   # Check subnets have proper tags
   aws ec2 describe-subnets --filters "Name=tag:kubernetes.io/cluster/cluster-name,Values=shared"
   ```

3. **Check IAM Role:**
   ```bash
   aws iam get-role --role-name eks-cluster-role
   aws iam list-attached-role-policies --role-name eks-cluster-role
   ```

#### Problem: "Node group fails to create"
```
Error: NodeCreationFailure: Instances failed to join the kubernetes cluster
```

**Solutions:**

1. **Check Security Groups:**
   ```bash
   # Verify security group rules allow communication
   aws ec2 describe-security-groups --group-ids sg-xxxxxxxxx
   ```

2. **Verify IAM Node Group Role:**
   ```bash
   aws iam list-attached-role-policies --role-name eks-node-group-role
   ```

3. **Check EC2 Instance Logs:**
   ```bash
   # SSH to worker node and check logs
   sudo tail -f /var/log/cloud-init-output.log
   sudo journalctl -u kubelet
   ```

### 4. Networking Issues

#### Problem: "VPC creation fails"
```
Error: error creating VPC: InvalidVpc.Range: The CIDR '10.0.0.0/16' conflicts with another VPC
```

**Solutions:**

1. **Change VPC CIDR:**
   Update `vpc_cidr` in your tfvars file:
   ```hcl
   vpc_cidr = "10.1.0.0/16"  # Use different CIDR
   ```

2. **Check existing VPCs:**
   ```bash
   aws ec2 describe-vpcs --query 'Vpcs[*].CidrBlock'
   ```

#### Problem: "Subnet creation fails"
```
Error: InvalidSubnet.Range: The CIDR '10.0.1.0/24' conflicts with another subnet
```

**Solutions:**

1. **Update subnet CIDRs:**
   Ensure all subnets use non-overlapping ranges within your VPC CIDR.

2. **Check existing subnets:**
   ```bash
   aws ec2 describe-subnets --query 'Subnets[*].{CIDR:CidrBlock,VPC:VpcId}'
   ```

### 5. Add-ons and Controllers Issues

#### Problem: "AWS Load Balancer Controller not working"
```
Error: failed to get AWS Load Balancer Controller service
```

**Solutions:**

1. **Check Controller Pods:**
   ```bash
   kubectl get pods -n kube-system | grep aws-load-balancer-controller
   kubectl logs -n kube-system deployment/aws-load-balancer-controller
   ```

2. **Verify OIDC Provider:**
   ```bash
   aws eks describe-cluster --name cluster-name --query "cluster.identity.oidc.issuer" --output text
   ```

3. **Check Service Account:**
   ```bash
   kubectl describe serviceaccount aws-load-balancer-controller -n kube-system
   ```

#### Problem: "Cluster Autoscaler not scaling"
```
Warning: failed to get node group information
```

**Solutions:**

1. **Check Autoscaler Logs:**
   ```bash
   kubectl logs -n kube-system deployment/cluster-autoscaler
   ```

2. **Verify IAM Permissions:**
   ```bash
   # Check if autoscaler can list node groups
   aws eks list-nodegroups --cluster-name cluster-name
   ```

3. **Check Node Group Tags:**
   ```bash
   aws eks describe-nodegroup --cluster-name cluster-name --nodegroup-name node-group-name
   ```

### 6. Resource Limits and Quotas

#### Problem: "InsufficientCapacity" or quota errors
```
Error: InsufficientCapacity: We currently do not have sufficient m5.large capacity
```

**Solutions:**

1. **Try different instance types:**
   ```hcl
   node_group_instance_types = ["t3.medium", "t3.large", "m5.large"]
   ```

2. **Check AWS Service Quotas:**
   ```bash
   aws service-quotas get-service-quota --service-code ec2 --quota-code L-1216C47A
   ```

3. **Use Spot instances for non-production:**
   ```hcl
   node_group_capacity_type = "SPOT"
   ```

### 7. GitHub Actions Workflow Issues

#### Problem: "Workflow not triggering"
**Solutions:**

1. **Check workflow file syntax:**
   Use GitHub's workflow validator or yamllint:
   ```bash
   yamllint .github/workflows/terraform-plan.yml
   ```

2. **Verify file paths:**
   Ensure paths in workflow triggers match your repository structure.

#### Problem: "Matrix strategy fails"
**Solutions:**

1. **Check environment files exist:**
   Verify all referenced environment files exist:
   ```bash
   ls terraform/environments/*/terraform.tfvars
   ```

2. **Validate tfvars syntax:**
   ```bash
   terraform validate -var-file="environments/dev/terraform.tfvars"
   ```

## 🔧 Debug Commands

### Terraform Debugging
```bash
# Enable detailed logging
export TF_LOG=DEBUG
export TF_LOG_PATH=terraform.log

# Validate configuration
terraform validate

# Plan with detailed output
terraform plan -detailed-exitcode

# Show current state
terraform show

# List all resources
terraform state list

# Import existing resources
terraform import aws_eks_cluster.main cluster-name
```

### AWS CLI Debugging
```bash
# Enable debug mode
aws configure set cli_read_timeout 0
aws configure set cli_follow_redirects false

# Check AWS credentials
aws sts get-caller-identity

# Test specific service permissions
aws eks list-clusters --region eu-west-1
aws ec2 describe-vpcs --max-items 5
```

### Kubernetes Debugging
```bash
# Check cluster info
kubectl cluster-info

# Get node details
kubectl describe nodes

# Check system pods
kubectl get pods --all-namespaces

# View events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check specific pod logs
kubectl logs -n kube-system deployment/coredns
```

## 📊 Monitoring and Alerts

### Set up monitoring
```bash
# Install metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces
```

### CloudWatch queries
```bash
# Check EKS cluster logs
aws logs describe-log-groups --log-group-name-prefix "/aws/eks/"

# Filter logs
aws logs filter-log-events --log-group-name "/aws/eks/cluster-name/cluster" --filter-pattern "ERROR"
```

## 🚀 Performance Optimization

### Terraform Performance
```bash
# Use parallelism flag
terraform apply -parallelism=30

# Reduce plan output
terraform plan -compact-warnings

# Use target for specific resources
terraform apply -target=module.vpc
```

### EKS Performance
```bash
# Optimize kubelet configuration
# Check current kubelet config
kubectl describe configmap kubelet-config -n kube-system

# Monitor cluster performance
kubectl get --raw /metrics | grep -E "apiserver_request_duration_seconds|etcd_request_duration_seconds"
```

## 📝 Maintenance Tasks

### Regular Maintenance
1. **Update Terraform providers:**
   ```bash
   terraform init -upgrade
   ```

2. **Update EKS cluster version:**
   ```hcl
   cluster_version = "1.29"  # Update version
   ```

3. **Rotate credentials:**
   ```bash
   # Update IAM role policies
   aws iam put-role-policy --role-name GitHubActions-TerraformRole --policy-name TerraformEKSPolicy --policy-document file://policy.json
   ```

4. **Clean up unused resources:**
   ```bash
   ./scripts/cleanup.sh
   ```

## 📞 Getting Help

If issues persist:

1. **Check AWS Service Health Dashboard**
2. **Review AWS CloudTrail logs**
3. **Check Terraform Registry documentation**
4. **Submit GitHub issue with:**
   - Terraform version
   - AWS provider version
   - Full error messages
   - Sanitized configuration files

## 🔐 Security Troubleshooting

### Common security issues:

1. **Overly permissive security groups:**
   ```bash
   # Audit security group rules
   aws ec2 describe-security-groups --query 'SecurityGroups[*].{GroupId:GroupId,IpPermissions:IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]]}'
   ```

2. **Public subnets for worker nodes:**
   ```bash
   # Check if worker nodes are in private subnets
   aws eks describe-nodegroup --cluster-name cluster-name --nodegroup-name node-group-name
   ```

3. **Missing encryption:**
   ```bash
   # Verify EKS cluster encryption
   aws eks describe-cluster --name cluster-name --query 'cluster.encryptionConfig'
   ```
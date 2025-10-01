#!/bin/bash

# Cleanup script for EKS Terraform Infrastructure
# This script helps clean up resources that might not be destroyed by terraform destroy

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="eu-west-1"

echo -e "${BLUE}🧹 Starting cleanup of EKS infrastructure...${NC}"

# Function to check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}❌ AWS CLI is not installed. Please install it first.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ AWS CLI is installed${NC}"
}

# Function to list and clean EKS clusters
cleanup_eks_clusters() {
    echo -e "${YELLOW}🔍 Looking for EKS clusters...${NC}"
    
    CLUSTERS=$(aws eks list-clusters --region ${AWS_REGION} --query 'clusters[?contains(@, `eks-`) || contains(@, `terraform`)]' --output text)
    
    if [ -n "$CLUSTERS" ]; then
        echo -e "${YELLOW}Found EKS clusters:${NC}"
        for cluster in $CLUSTERS; do
            echo -e "${BLUE}  - ${cluster}${NC}"
            
            # List node groups
            NODE_GROUPS=$(aws eks list-nodegroups --cluster-name $cluster --region ${AWS_REGION} --query 'nodegroups' --output text)
            if [ -n "$NODE_GROUPS" ]; then
                echo -e "${YELLOW}    Node groups: ${NODE_GROUPS}${NC}"
            fi
        done
        
        echo -e "${RED}⚠️ Found EKS clusters. Please delete them manually or via terraform destroy.${NC}"
    else
        echo -e "${GREEN}✅ No EKS clusters found${NC}"
    fi
}

# Function to clean up orphaned security groups
cleanup_security_groups() {
    echo -e "${YELLOW}🔍 Looking for orphaned security groups...${NC}"
    
    # Find security groups with eks or terraform in the name
    SG_IDS=$(aws ec2 describe-security-groups --region ${AWS_REGION} \
        --query 'SecurityGroups[?contains(GroupName, `eks`) || contains(GroupName, `terraform`)].GroupId' \
        --output text)
    
    if [ -n "$SG_IDS" ]; then
        echo -e "${YELLOW}Found security groups that might be orphaned:${NC}"
        for sg_id in $SG_IDS; do
            SG_NAME=$(aws ec2 describe-security-groups --group-ids $sg_id --region ${AWS_REGION} --query 'SecurityGroups[0].GroupName' --output text)
            echo -e "${BLUE}  - ${sg_id} (${SG_NAME})${NC}"
        done
        echo -e "${YELLOW}ℹ️ Check these security groups manually before deleting${NC}"
    else
        echo -e "${GREEN}✅ No orphaned security groups found${NC}"
    fi
}

# Function to clean up elastic IPs
cleanup_elastic_ips() {
    echo -e "${YELLOW}🔍 Looking for unassociated Elastic IPs...${NC}"
    
    EIPS=$(aws ec2 describe-addresses --region ${AWS_REGION} \
        --query 'Addresses[?!AssociationId].AllocationId' --output text)
    
    if [ -n "$EIPS" ]; then
        echo -e "${YELLOW}Found unassociated Elastic IPs:${NC}"
        for eip in $EIPS; do
            echo -e "${BLUE}  - ${eip}${NC}"
        done
        echo -e "${YELLOW}ℹ️ Consider releasing these Elastic IPs if they're not needed${NC}"
    else
        echo -e "${GREEN}✅ No unassociated Elastic IPs found${NC}"
    fi
}

# Function to clean up load balancers
cleanup_load_balancers() {
    echo -e "${YELLOW}🔍 Looking for load balancers...${NC}"
    
    # Check ALBs and NLBs
    ALBS=$(aws elbv2 describe-load-balancers --region ${AWS_REGION} \
        --query 'LoadBalancers[?contains(LoadBalancerName, `k8s`) || contains(LoadBalancerName, `eks`)].LoadBalancerArn' \
        --output text)
    
    if [ -n "$ALBS" ]; then
        echo -e "${YELLOW}Found load balancers:${NC}"
        for alb in $ALBS; do
            ALB_NAME=$(aws elbv2 describe-load-balancers --load-balancer-arns $alb --region ${AWS_REGION} --query 'LoadBalancers[0].LoadBalancerName' --output text)
            echo -e "${BLUE}  - ${ALB_NAME}${NC}"
        done
        echo -e "${YELLOW}ℹ️ These load balancers might be managed by Kubernetes controllers${NC}"
    else
        echo -e "${GREEN}✅ No Kubernetes-related load balancers found${NC}"
    fi
}

# Function to clean up CloudWatch log groups
cleanup_cloudwatch_logs() {
    echo -e "${YELLOW}🔍 Looking for EKS CloudWatch log groups...${NC}"
    
    LOG_GROUPS=$(aws logs describe-log-groups --region ${AWS_REGION} \
        --query 'logGroups[?contains(logGroupName, `/aws/eks/`) || contains(logGroupName, `terraform`)].logGroupName' \
        --output text)
    
    if [ -n "$LOG_GROUPS" ]; then
        echo -e "${YELLOW}Found CloudWatch log groups:${NC}"
        for log_group in $LOG_GROUPS; do
            echo -e "${BLUE}  - ${log_group}${NC}"
        done
        
        read -p "Do you want to delete these log groups? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for log_group in $LOG_GROUPS; do
                aws logs delete-log-group --log-group-name $log_group --region ${AWS_REGION}
                echo -e "${GREEN}✅ Deleted log group: ${log_group}${NC}"
            done
        fi
    else
        echo -e "${GREEN}✅ No EKS-related CloudWatch log groups found${NC}"
    fi
}

# Function to check for volumes
cleanup_ebs_volumes() {
    echo -e "${YELLOW}🔍 Looking for unattached EBS volumes...${NC}"
    
    VOLUMES=$(aws ec2 describe-volumes --region ${AWS_REGION} \
        --query 'Volumes[?State==`available`].VolumeId' --output text)
    
    if [ -n "$VOLUMES" ]; then
        echo -e "${YELLOW}Found unattached EBS volumes:${NC}"
        for volume in $VOLUMES; do
            VOLUME_SIZE=$(aws ec2 describe-volumes --volume-ids $volume --region ${AWS_REGION} --query 'Volumes[0].Size' --output text)
            echo -e "${BLUE}  - ${volume} (${VOLUME_SIZE}GB)${NC}"
        done
        echo -e "${YELLOW}ℹ️ Check if these volumes are needed before deleting${NC}"
    else
        echo -e "${GREEN}✅ No unattached EBS volumes found${NC}"
    fi
}

# Function to show cost analysis
show_cost_analysis() {
    echo -e "${BLUE}💰 Cost Analysis${NC}"
    echo -e "${YELLOW}Run this command to see current costs:${NC}"
    echo -e "${GREEN}aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-12-31 --granularity MONTHLY --metrics UnblendedCost --group-by Type=DIMENSION,Key=SERVICE${NC}"
}

# Function to generate cleanup report
generate_cleanup_report() {
    echo -e "${BLUE}📊 Generating cleanup report...${NC}"
    
    REPORT_FILE="cleanup-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "EKS Infrastructure Cleanup Report"
        echo "Generated on: $(date)"
        echo "Region: ${AWS_REGION}"
        echo "================================"
        echo ""
        
        echo "EKS Clusters:"
        aws eks list-clusters --region ${AWS_REGION} --output table || echo "No clusters found"
        echo ""
        
        echo "Security Groups (EKS/Terraform related):"
        aws ec2 describe-security-groups --region ${AWS_REGION} \
            --query 'SecurityGroups[?contains(GroupName, `eks`) || contains(GroupName, `terraform`)].{Name:GroupName,ID:GroupId}' \
            --output table || echo "No security groups found"
        echo ""
        
        echo "Unattached EBS Volumes:"
        aws ec2 describe-volumes --region ${AWS_REGION} \
            --query 'Volumes[?State==`available`].{ID:VolumeId,Size:Size,Type:VolumeType}' \
            --output table || echo "No unattached volumes found"
        
    } > $REPORT_FILE
    
    echo -e "${GREEN}✅ Cleanup report saved to: ${REPORT_FILE}${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}🚀 Starting infrastructure cleanup check...${NC}"
    
    check_aws_cli
    cleanup_eks_clusters
    cleanup_security_groups
    cleanup_elastic_ips
    cleanup_load_balancers
    cleanup_cloudwatch_logs
    cleanup_ebs_volumes
    show_cost_analysis
    generate_cleanup_report
    
    echo -e "${GREEN}✅ Cleanup check completed!${NC}"
    echo -e "${YELLOW}⚠️ Always verify resources before deleting them manually${NC}"
}

# Run main function
main "$@"
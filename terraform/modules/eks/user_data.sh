#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh ${cluster_name} ${bootstrap_arguments}
echo "EKS Node bootstrap completed"
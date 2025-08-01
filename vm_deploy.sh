#!/bin/bash
set -euo pipefail

cd /var/lib/semaphore/terraform
tofu apply -auto-approve

tofu output -json > tf_outputs.json

VM_IP=$(jq -r '.vm1_ip.value' tf_outputs.json)
VM_PORT=$(jq -r '.vm1_ssh_port.value' tf_outputs.json)

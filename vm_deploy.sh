# #!/bin/bash
# set -euo pipefail

# cd /mnt/localproject/terraform
# tofu apply -auto-approve

# tofu output -json > tf_outputs.json

# VM_IP=$(jq -r '.vm1_ip.value' tf_outputs.json)
# VM_PORT=$(jq -r '.vm1_ssh_port.value' tf_outputs.json)

#!/bin/bash
set -e

cd /mnt/localproject/terraform
tofu init
tofu plan -out=tfplan
tofu apply -auto-approve tfplan

# Extract VM IP for Ansible use:
VM_IP=$(tofu output -raw vm_ip)

# # Run Ansible playbook (assume ansible installed and playbook.yml present)
# ANSIBLE_HOSTS=$(mktemp)
# echo "[ubuntu_vm]" > $ANSIBLE_HOSTS
# echo "$VM_IP" >> $ANSIBLE_HOSTS

# ansible-playbook -i $ANSIBLE_HOSTS --user=ubuntu --private-key=/path/to/ssh_key playbook.yml

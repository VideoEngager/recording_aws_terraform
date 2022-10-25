aws_account_id=""
access_key=""
secret_key=""

deployment_region = ""

ec2_type = "t3.small"
pn_ec2_type = "t3.medium"
docker_ec2_type = "t3.medium"

vpc_cidr_block ="10.231.0.0/16"

nodes_count = 2

use_play_service = false
play_ec2_type = "t3.small"

use_private_link = false
use_elastic_ip = true

use_docker_workers = false
aws_ecr_docker_token = ""

#steps:
# 1. Fill variables
# 2. Install terraform
# 3. terraform init -reconfigure
# 4. terraform  plan
# 5. terraform  apply --auto-approve
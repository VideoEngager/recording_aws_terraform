aws_account_id=""
access_key=""
secret_key=""

deployment_region = ""
availability_zone_1 = "a"
availability_zone_2 = "b"

ec2_type = "t3.small"
pn_ec2_type = "t3.medium"

vpc_cidr_block ="10.231.0.0/16"

nodes_count = 2


#steps:
# 1. Fill variables
# 2. Install terraform
# 3. terraform init -reconfigure
# 4. terraform  plan
# 5. terraform  apply --auto-approve
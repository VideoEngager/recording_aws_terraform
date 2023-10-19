aws_account_id=""
access_key=""
secret_key=""

deployment_region = ""
vpc_cidr_block ="X.X.X.X/16"

# [optional variables]
#
# ec2_type = ""
# pn_ec2_type = ""
# docker_ec2_type = ""

# use_play_service = true
# use_archiver_service = true
# play_ec2_type = "t3.small"

# use_private_link = false
# use_elastic_ip = false

# use_docker_workers = false
# aws_ecr_docker_token = ""

# isEFSEncrypted = false
# ami_version = "XXXXX"

#steps:
# 1. Fill variables
# 2. Install terraform
# 3. terraform init -reconfigure
# 4. terraform  plan
# 5. terraform  apply --auto-approve
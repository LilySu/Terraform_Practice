# VPC Peering
# we pair dev account vpc with security vpc
# by creating a peering role to give the dev account user access to security vpc
# 1. in the security account, we create a json policy that allows description of
# of peering connections and accept peering connections from another vpc
# 2. we create the iam role and assign the policy to the role
# so if someone assumes the role, they will get the permissions from the policy
# 3. in the dev account, we create a json policy that allows user to assume
# the peering role in the security account then assign the policy to a peering group

# Make users manually named ElVasquez and JasonGibson with adminaccess for each
# Delete any vpc_peer_group connections that were previously assigned accidentally
# assign their secret access keys to aws config
# rename terraform.tfvars.example to terraform.tfvars
# rerun terraform init
# record the arn returned in the output
#############################################################################
# VARIABLES
#############################################################################

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "peering_users" {
  type = list(string)
}

#############################################################################
# PROVIDERS
#############################################################################

# same region, different aws profiles
# two different providers using 2 different aws accounts

provider "aws" {
  version = "~> 2.0"
  region  = var.region
  alias   = "infra"
  profile = "infra" # from aws configure --profile that was created
}

provider "aws" {
  version = "~> 2.0"
  region  = var.region
  alias   = "sec"
  profile = "sec"
}

#############################################################################
# DATA SOURCES
#############################################################################


# retrieves identity of provider
# we will need the account id for configuring roles
data "aws_caller_identity" "infra" {
  provider = aws.infra
}

data "aws_caller_identity" "sec" {
  provider = aws.sec
}

#############################################################################
# RESOURCES
#############################################################################

# Create a policy to allow peering acceptance

# create iam peering policy for peering role within the security account
# we accept and descripe peering policies in our actions
resource "aws_iam_role_policy" "peering_policy" {
  name     = "vpc_peering_policy"
  role     = aws_iam_role.peer_role.id
  provider = aws.sec

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "ec2:AcceptVpcPeeringConnection",
          "ec2:DescribeVpcPeeringConnections"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  }
  EOF
}

# Create a role that can be assumed by the infra account
# we are creating this role in the security account
resource "aws_iam_role" "peer_role" {
  name     = "peer_role"
  provider = aws.sec

# another account can assume role, so sts AssumeRole
# the entity that can assume the role is wrapped as a variable
# ${data.aws_caller_identity.infra.account_id}
# where we need the aws_caller_identity account id
  assume_role_policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${data.aws_caller_identity.infra.account_id}:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {}
    }
  ]
}
  EOF
}

# Create a group that can accept peering connections
# create iam group in infra account
resource "aws_iam_group" "peering" {

  name     = "VPCPeering"
  provider = aws.infra

}

# Add members to the group
# we assign sample user Velasquez to group
resource "aws_iam_group_membership" "peering-members" {
  name     = "VPCPeeringMembers"
  provider = aws.infra
  # pulls from our variable our list of users
  users = var.peering_users
  # what group are we adding users to
  group = aws_iam_group.peering.name
}

# Create a group policy that can assume the role in sec
# we assign policy to group that we just created
# all happening in infra account
resource "aws_iam_group_policy" "peering-policy" {
  name     = "peering-policy"
  group    = aws_iam_group.peering.id
  provider = aws.infra
  # Policy is an assume action
  # Resource is role we created in the security account, referencing the arn
  # So if you have this policy, you can assume the role in the security account
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": {
    "Effect": "Allow",
    "Action": "sts:AssumeRole",
    "Resource": "${aws_iam_role.peer_role.arn}"
  }
}
EOF
}

#############################################################################
# OUTPUTS
#############################################################################
# we output peer role arn
output "peer_role_arn" {
  value = aws_iam_role.peer_role.arn
}

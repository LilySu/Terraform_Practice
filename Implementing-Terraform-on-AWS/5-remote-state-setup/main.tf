# Terraform State Data: is the information that maps your configuration to the real
# world resources that has been deployed in your public cloud provider

# ie. if you define a peer_vpc in your config that maps to an id in a state file that
# maps to an actual vpc in aws

# If you don't tell terraform where to put the data, terraform puts the data
# in the same directory as your configuration locally

# To move the data somewhere else to safeguard data and allow for collaboration.

# location = backend
# local backend = when terraform stores data in same directory as configuration
# remote backends:
# standdard: normal
# enhanced: also runs terraform processes - terraform cloud and terraform enterprise

# locking: backends that support locking will ensure another change is not being
# implemented while you are currently making a change
# workspaces: same configuration for multiple environments stored ina workplace
# construct

# Locking Support involes 2 things:
# 1. You can write state data to S3 bucket
# 2. DynamoDB table terraform puts the locking entry when it is manipulating state
# in an S3 bucket

# workspaces can be done complete in S3
# granular control can be done in S3 bucket
# S3 supports encryption

# Authentification
# Instance profiles can be given to an ec2 instance that contains permission
# to write to S3 bucket and DynamoDB table
# access & secret keys ok
# credentials file and profile on awscli
# session token

# because we set the environment variable by inputting  '$env:AWS_PROFILE="infra"'
# in command line, this is our authentification method

# Organization
# It is recommended to keep S3 and dynamodb in the admin account
# Each admin dev may have access to admin account plus either a QA account,
# staging account, production account, depending on their role
# write their state data to admin account and deploy or provision infrastructure
# by assuming the QA role in the QA account

# storing state data from other accounts lock down access to it to a degree

# granular permissions cannot be assigned to dynamodb table


# Migrating Terraform State
# Migrate to remote state
# update backend configuration
# run terraform init (initializes backend)
# confirm state migration
# back up state just in case

# Backend Configuration - you need to specify type of backend
# terraform {
#   backend "s3" {
#   }
# }
# you can hardcode the bucket and keyname like this
# terraform {
#   backend "s3" {
#     bucket = "globo-infra-12345"
#     key = "terraform-state"
#     region = "us-east-1"
#   }
# }
# You can't use variables in your backend configuration because it loads first
# to specify config in command line:
# terraform init -backend-config="profile=infra"

# Summary
# use remote state by default
# AWS S3 and DynamoDB supports locking and workspaces in a collaborative
# environemnt where there may be multiple deployment environments

##################################################################################
# VARIABLES
##################################################################################
# region where the bucket is stored
variable "region" {
  type    = string
  default = "us-east-1"
}

#Bucket variables
variable "aws_bucket_prefix" {
  type    = string
  default = "globo" # naming prefix
}

variable "aws_dynamodb_table" {
  type    = string
  default = "globo-tfstatelock"
}
# defines users in permissions groups
variable "full_access_users" {
  type    = list(string)
  default = []

}
# defines users in permissions groups
variable "read_only_users" {
  type    = list(string)
  default = []
}

##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  version = "~>2.0"
  region  = var.region
}

##################################################################################
# RESOURCES
##################################################################################
# the name of a S3 bucket needs to be globally unique so we append a random
# number to make sure the name will be globally unique
resource "random_integer" "rand" {
  min = 10000
  max = 99999
}
# make a unique bucket and table name
locals {

  dynamodb_table_name = "${var.aws_dynamodb_table}-${random_integer.rand.result}"
  bucket_name         = "${var.aws_bucket_prefix}-${random_integer.rand.result}"
}
# the dynamodb just has to be locally universal
resource "aws_dynamodb_table" "terraform_statelock" {
  name           = local.dynamodb_table_name
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "LockID" # requirement when dynamodb is used with S3 for locking

  attribute {
    name = "LockID"
    type = "S" # String, requirement when dynamodb is used with S3 for locking
  }
}

resource "aws_s3_bucket" "state_bucket" {
  bucket        = local.bucket_name
  acl           = "private"
  force_destroy = true # bucket will be deleted even if not empty

  versioning {
    enabled = true
  }

}

resource "aws_iam_group" "bucket_full_access" {

  name = "${local.bucket_name}-full-access"

}

resource "aws_iam_group" "bucket_read_only" {

  name = "${local.bucket_name}-read-only"

}

# Add members to the group

resource "aws_iam_group_membership" "full_access" {
  name = "${local.bucket_name}-full-access"

  users = var.full_access_users

  group = aws_iam_group.bucket_full_access.name
}

resource "aws_iam_group_membership" "read_only" {
  name = "${local.bucket_name}-read-only"

  users = var.read_only_users

  group = aws_iam_group.bucket_read_only.name
}

resource "aws_iam_group_policy" "full_access" {
  name  = "${local.bucket_name}-full-access"
  group = aws_iam_group.bucket_full_access.id
  # "s3:*": allow statement 1, can do anything in s3
  # we can do anything on bucket and anything inside bucket
  # "arn:aws:s3:::${local.bucket_name}",
  # "arn:aws:s3:::${local.bucket_name}/*"
  # "Action": ["dynamodb:*"] - we allow any action on dynamodb
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::${local.bucket_name}",
                "arn:aws:s3:::${local.bucket_name}/*"
            ]
        },
                {
            "Effect": "Allow",
            "Action": ["dynamodb:*"],
            "Resource": [
                "${aws_dynamodb_table.terraform_statelock.arn}"
            ]
        }
   ]
}
EOF
}

resource "aws_iam_group_policy" "read_only" {
  name  = "${local.bucket_name}-read-only"
  group = aws_iam_group.bucket_read_only.id
  # We grant anything get and list in S3
  # so we can list anything in the bucket and get objects
  # but cannot change or write to the object
  # "s3:Get*",
  # "s3:List*"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:Get*",
                "s3:List*"
            ],
            "Resource": [
                "arn:aws:s3:::${local.bucket_name}",
                "arn:aws:s3:::${local.bucket_name}/*"
            ]
        }
   ]
}
EOF
}

##################################################################################
# OUTPUT
##################################################################################
# we output the name of bucket and name of table
output "s3_bucket" {
  value = aws_s3_bucket.state_bucket.bucket
}

output "dynamodb_statelock" {
  value = aws_dynamodb_table.terraform_statelock.name
}
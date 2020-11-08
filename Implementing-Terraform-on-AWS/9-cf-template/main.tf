# # Cloudformation templates in terraform configuration
# # to deploy a aws cloudformation stack we have to deploy a resource cloud
# # formation stack
# resource "aws_cloudformation_stack" "stack" {
#   name = "app-stack"
#   # provide template information
#   # our method is pulling it in from a file using file information
#   # this could also be defined in line
#   # one can also reference a template url where the template is already stored
#   template_body = file("app-stack.template")
#   # provide a map of parameter name and template you want to submit
#   parameters = {}
#   # additional arguments such as on failure what should the stack do
#   on_failure = "ROLLBACK"
# }

# We have a separate application codified in a CloudFormation template
# Inside the template is a DynamoDB and Lambda function
# They don't live on a vpc
# In our next configuration Lambda will need to talk to servers in
# public subnets

# as part of the template, there is a vpc integration where lambda puts
# network interfaces in public subnets to talk to those services

# we use our existing dev-vpc as our data source to feed into
# CloudFormation template

##################################################################################
# VARIABLES
##################################################################################

variable "region" {
  type    = string
  default = "us-east-1"
}
# we are going to create a bucket
variable "aws_bucket_prefix" {
  type    = string
  default = "globo"
}
# we will be referencing dev_vpc network state so we need bucket, key
# and region
variable "network_state_bucket" {
  type        = string
  description = "name of bucket used for network state"
}

variable "network_state_key" {
  type        = string
  description = "name of key used for network state"
  default     = "networking/dev-vpc/terraform.tfstate"
}

variable "network_state_region" {
  type        = string
  description = "region used for network state"
  default     = "us-east-1"
}
# we generate a bucket name to store our lambda function
locals {
  bucket_name = "${var.aws_bucket_prefix}-lambda-${random_integer.rand.result}"
}

##################################################################################
# PROVIDERS
##################################################################################
# we are using the app profile
provider "aws" {
  version = "~>2.0"
  region  = var.region
  profile = "app"
}

##################################################################################
# Data sources
##################################################################################
# we are using terraform state resources
# getting network information from the dev_vpc
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.network_state_bucket
    key    = var.network_state_key
    region = var.network_state_region
  }
}

##################################################################################
# RESOURCES
##################################################################################
# generate random integer
resource "random_integer" "rand" {
  min = 10000
  max = 99999
}

# Deploy the S3 bucket
# this will hold the lambda function code because the cloud formation template
# assumes that the code is sitting in an s3 bucket
# so we have to provide the information to it
# this is something that the template didn't do before
resource "aws_s3_bucket" "lambda_functions" {
  bucket        = local.bucket_name
  acl           = "private"
  force_destroy = true
}

# Put the Lambda function in the S3 bucket
# once we deploy the s3 bucket, we will put the publishOrders.zip into the s3 bucket
# so that it is accessible to our cloudformation template
resource "aws_s3_bucket_object" "lambda_function" {
  key        = "publishOrders.zip"
  bucket     = aws_s3_bucket.lambda_functions.id
  source     = "publishOrders.zip"
}

# Create a Security Group for Lambda
# Lambda requires a security group
resource "aws_security_group" "lambda_sg" {
  name        = "lambda-security-group"
  description = "Security group for Lambda"
  # we use the terraform remote state data source to get the vpc id where the
  # security group should be created
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
}

# Deploy the template
# The Stack Deployment
resource "aws_cloudformation_stack" "orders_stack" {
  name = "orders-stack"
  capabilities = ["CAPABILITY_IAM"] # enables certain capabilities on the stack
  # within the template we will be creating an iam role
  # so we are giving this capability, now CloudFormation will be able to create
  # the resource

  parameters = {
      FunctionBucket = local.bucket_name
      # where the function is located inside the bucket
      FunctionKey = "publishOrders.zip"
      # we just created this security group
      LambdaSecurityGroup = aws_security_group.lambda_sg.id
      # list of subnet id's where lambda should be putting those interfaces
      # in this case we want it in the public subnets
      # we are using the join function because the template expects a comma delimited
      # string of subnet id's
      # this will convert the existing list to a string
      SubnetIds = join(",",data.terraform_remote_state.network.outputs.public_subnets)
  }
  # submit the template body
  template_body = file("${path.module}/lambda.template")
}

##################################################################################
# OUTPUT
##################################################################################
# all outputs from this stack deployment
output "template_output" {
  value = aws_cloudformation_stack.orders_stack.outputs
}

# Regarding the file lambda.template
# this is the template to deploy the stack, yaml could also be used

# define parameters for dynamodb table attributes and keys
# define read and write capacity units

# define FunctionKey, LambaSecurityGroup, SubnetIds

# Resources

# DyanamoDB table
# - the myDynamoDBTable named GloboOrders
# - set up a StreamSpecification and StreamViewType for the lambda function
# - set up AttributeDefinitions:
    # HashKeyElementName = parameters
    # HashKeyElementType = timestamp
      # - set up a KeySchema
# - ProvisionedThroughput for read and write capacity units

# Role
# permissions to assume the role with AssumeRolePolicyDocument
  # Policies - allow it to envoke itself
  # Interact with logs
  # Action: get information from dynamodb as well as describe streams from
  # the dynamodb table
  # permission to publish to SNS
  # The ability to create, describe and delete the network interface

# The Lambda Function Itself: "orderLambdaFunction"
# Code: specifies where the code is, which is the S3 bucket,
# refer to S3Key, which is stored in the S3 bucket as "FunctionKey"
# Assign the Role created for the Lambda Function

# Set handler and runtime for node.js
# In VPCConfig, it needs the security group id to associate with the
# network interface that we will create
# and the subet id where it will create the network interface

# We output the name of the dynamodb table,
# and the arn of the lambda function

# Summary
# You really need to think about how to layer your configurations
# Try to keep your dependencies loosely coupled

# Each configuration should be its own atomic unit outside
# the other configurations

# You shouldn't have to drastically change other configuration
# When you make a change to one configuration

# CloudFormation is an option, you can create stacks from
# Terraform and consume the output of existing stacks in your
# Terraform configuration


# Key Takeaways
# multiple instances of an aws provider are needed when
# accounts and multiple regions are reasons why

# To authenticate, you can use
# profiles in your credentials file
# instance profiles associated with the ec2 instance or container in aws
# or access and secret keys stored in environment variables

# states can be stored remotely in s3 and dynamodb
# get state out of local drive and into something remote

# use source control to store configurations
# automation is used in codebuild and codepipeline to deploy
# what was in source control
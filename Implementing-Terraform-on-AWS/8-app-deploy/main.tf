# Layering Configurations
# from atomic deployments of configurations that are loosely coupled
# ie. region with 1 or more vpcs
# on top of this layer, a business logic app can be deployed
# on top of vpc
# the app needs a vpc but not that vpc, they are not tightly coupled
# lambda function may not be deployed in the same configuration
# lambda and dynamo db may be in the same configuration but
# lambda and your business logic app doesn't need the config to be shared
# referencing others loosely is loosely coupled

# Consuming Data Sources
# What kind of data sources do you want to reference?
# ie. accounts - retrieve account you are using
# list of availability zones
# ami's reference them
# get a list of vpc, security groups, subnets ie load balancer
# ec2 - for load balancing, for security groups

# How do you reference data sources?
# ie
# this is a way to get your account id based on the current provider that
# you are using
# if you don't reference a specific instance of your provider then
# you are going with a default provider
# otherwise provide the alias of your provider
# data "aws_caller_identity" "account" {
# }
# data "aws_availability_zones" "available" {
#  state = "available" # gives only zones that are currently available
# }
# to get a list of subnet id's
# you can tag by subnets that you want to retrieve
# data "aws_subnet_ids" "subnets" {
#   vpc = var.vpc_id
#   tags = {
#     "tier" = "application"
#   }
# }

# Case Study:
# Josh Magee wants to deploy applications in the dev-vpc
# in order to get information about the dev-vpc

# Methods
# query aws directly
# easier to query network state data in S3 bucket

# He wants to deploy an autoscale group across 2 public subnets
# and an application load balancer that is public facing
# also a mysql rds instance to each of the two subnets
# 1 database server master and 1 replica
# only 1 is deployed at a time

# He stores his state in a separate S3 bucket called application state
# that will be deployed as part of the configuration

# How do you reference Terraform Remote State as a Data Source?
# Create a data source configuration block

# data "terraform_remote_state" "networking" {
#   backend = "s3" # where can I find this remoe state data source

#   # config data for accessing this backend
#   # dynamodb is not in here because we are not trying to lock the data
#   # or change anything, we're simply reading information

#   # no authentification, aws uses the existing auth

#   config = {
#     bucket = var.net_bucket_name
#     key = var.net_bucket_key
#     region = var.net_bucket_region
#   }
# }

##################################################################################
# VARIABLES
##################################################################################

variable "region" {
  type    = string
  default = "us-east-1"
}

# this does not have a default variable because it depends on your deployment
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




##################################################################################
# PROVIDERS
##################################################################################
# we use the profile app, which is Joshua McGee's credentials
provider "aws" {
  version = "~>2.0"
  region  = var.region
  profile = "app"
}

##################################################################################
# Data sources
##################################################################################
# we had created a read-only group and had added the app profile to it
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.network_state_bucket
    key    = var.network_state_key
    region = var.network_state_region
  }
}
# we need an ami to deploy ec2 instances
# we could hardcode the ami id, but if we move to a different region it changes
data "aws_ami" "amazon_linux" {
  # gives us the most recent version of the ami that is available
  most_recent = true
  # sending the owners number to the amazon owner's id, unique id corresponding
  # to images managed by amazon
  owners      = ["137112412989"]

  filter {
    name = "name"
    # should retrieve a single ami image id
    values = [
      "amzn-ami-hvm-*-x86_64-gp2",
    ]
  }
  # we specify that the owner alias is amazon and it should be the case already
  # but no harm in specifying twice
  filter {
    name = "owner-alias"

    values = [
      "amazon",
    ]
  }
}


##################################################################################
# RESOURCES
##################################################################################
# generates random integers where we need a unique id
resource "random_integer" "rand" {
  min = 10000
  max = 99999
}

#####################
# RDS Security group
#####################
# for rds, we need to create security groups
resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group"
  description = "Security group for RDS"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
}
# output = any output we created with configuration we stored within this
# configuration state

# THE ONLY ATTRIBUTES THAT ARE AVAILABLE WHEN YOU REFERENCE REMOTE STATE
# ARE THOSE EXPOSED VIA AN OUTPUT
# in this case we are referencing vpc id - from 1-dev-vpc
# when we reference remote state as a data source these are the only ones
# available to us
# - vpc_id
# - db_subnet_group
# - public_subnets

# create rds security group
resource "aws_security_group_rule" "allow_asg" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.asg_sg.id
  security_group_id        = aws_security_group.rds_sg.id
}

# create security group role
resource "aws_security_group_rule" "egress_rds" {
  type              = "egress" # allows all traffic out
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds_sg.id
}

# to deploy our mysql environment, we use the rds module
# default module available in Terraform registry
module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "2.15.0"

  identifier = "globo-dev-db"

  engine            = "mysql"
  engine_version    = "5.7.19"
  instance_class    = "db.t2.large"
  allocated_storage = 5

  name                   = "globoappdb"
  username               = "globoadmin"
  password               = "YourPwdShouldBeLongAndSecure!"
  port                   = "3306"
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  iam_database_authentication_enabled = true

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  tags = {
    Owner       = "App"
    Environment = "dev"
  }

  # DB subnet group
  # we reference terraform remote source data source
  db_subnet_group_name = data.terraform_remote_state.network.outputs.db_subnet_group

  # DB parameter group
  family = "mysql5.7"

  # DB option group
  major_engine_version = "5.7"

  # Snapshot name upon DB deletion
  final_snapshot_identifier = "globo-app-db"

  # Database Deletion Protection
  deletion_protection = false

  parameters = [
    {
      name  = "character_set_client"
      value = "utf8"
    },
    {
      name  = "character_set_server"
      value = "utf8"
    }
  ]

  options = [
    {
      option_name = "MARIADB_AUDIT_PLUGIN"

      option_settings = [
        {
          name  = "SERVER_AUDIT_EVENTS"
          value = "CONNECT"
        },
        {
          name  = "SERVER_AUDIT_FILE_ROTATIONS"
          value = "37"
        },
      ]
    },
  ]
}

###########################################
# Launch configuration and Auto scale group
###########################################

resource "aws_security_group" "asg_sg" {
  name        = "asg-security-group"
  description = "Security group for ASG"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
}
# the autoscale group needs security group
# create a security group and put in vpc
resource "aws_security_group_rule" "allow_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.asg_sg.id
}

resource "aws_security_group_rule" "egress_lc" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.asg_sg.id
}

resource "aws_launch_configuration" "web_servers" {
  name            = "web-servers"
  image_id        = data.aws_ami.amazon_linux.id
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.asg_sg.id]
  # we pull information from user_data.txt
  user_data       = file("${path.module}/user_data.txt")
}
# create target group that will associate with load balancer
# this is our web service
resource "aws_lb_target_group" "web_servers" {
  name     = "web-servers-tg"
  # where traffic should come in to hit our target group
  port     = 80
  protocol = "HTTP"
  # same vpc we use for all our resources
  vpc_id   = data.terraform_remote_state.network.outputs.vpc_id
}

resource "aws_autoscaling_group" "web_servers" {
  name = "web-servers-asg"

  max_size         = 4
  min_size         = 0
  desired_capacity = 2
  # spins up 2 instances by default
  health_check_grace_period = 300
  health_check_type         = "EC2"

  launch_configuration = aws_launch_configuration.web_servers.name
  # what subnet should we spin instances in
  # we want it in the public subnet
  # we use the public subnet output
  vpc_zone_identifier = data.terraform_remote_state.network.outputs.public_subnets

  target_group_arns = [aws_lb_target_group.web_servers.arn]

}


###############################################
# Applicaiton load balancer
###############################################
# we also need a security group
resource "aws_security_group" "alb_sg" {
  name        = "alb-security-group"
  description = "Security group for ALB"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
}
# ingress role to allows port 80 in
resource "aws_security_group_rule" "allow_http_alb" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_sg.id
}

resource "aws_security_group_rule" "egress_alb" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_sg.id
}
# we deploy load balancer
resource "aws_lb" "web_server" {
  name               = "web-server-alb"
  internal           = false
  load_balancer_type = "application"
  # security group we just created
  security_groups    = [aws_security_group.alb_sg.id]
  # same subnet we reference for our autoscale group
  subnets            = data.terraform_remote_state.network.outputs.public_subnets

  enable_deletion_protection = false

  tags = {
    Environment = "development"
  }
}
# listener listens to requests in the front end
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.web_server.arn
  port              = "80" # listen on port 80 for http protocol
  protocol          = "HTTP"
  # when we get a request on port 80, we forward the request
  # to the target group of web servers that we have created
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_servers.arn
  }
}

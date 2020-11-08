#############################################################################
# VARIABLES
#############################################################################

# The following can be overriden with any tfvars file or -var commands

variable "region" {
  type    = string
  default = "us-east-1"
}


variable "vpc_cidr_range" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "database_subnets" {
  type = list(string)
  default = ["10.0.8.0/24", "10.0.9.0/24"]
}


#############################################################################
# PROVIDERS
#############################################################################

# To stay in version 2, whether 2.1 or 2.9, but won't bump you to 3.0
provider "aws" {
  version = "~> 2.0"
  region  = var.region
}

#############################################################################
# DATA SOURCES
#############################################################################

# Pulls full list of availability zones so we can use them when configuring vpc
data "aws_availability_zones" "azs" {}

#############################################################################
# RESOURCES
#############################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws" # We are using from the Terraform registry
  version = "2.33.0"

  name = "dev-vpc"
  cidr = var.vpc_cidr_range

  # availability zones: slice off a piece of list
  azs            = slice(data.aws_availability_zones.azs.names, 0, 2)
  public_subnets = var.public_subnets

  # Database subnets
  database_subnets  = var.database_subnets
  database_subnet_group_tags = {
    subnet_type = "database"
  }

  tags = {
    Environment = "dev"
    Team        = "infra"
  }

}

#############################################################################
# OUTPUTS
#############################################################################

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "db_subnet_group" {
  value = module.vpc.database_subnet_group
}

output "public_subnets" {
  value = module.vpc.public_subnets
}



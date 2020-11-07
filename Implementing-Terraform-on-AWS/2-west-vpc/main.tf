# Providers - used for multiple regions, accounts, cloud services
# Multiple Providers in a normal situation: Alias
# provider "aws" {
#   alias = "west" # name of instance of provider, name label of provider
#   version = "~> 2.0"
#   region  = var.region_2
# }

# Multiple Providers using a module:
# # Map provider like this unless using default provider:
# resource "aws_iam_role" "sec-role" {
#   provider = aws.security
# }
# module "vpc" {
#   providers = {
#     aws = aws.prod-east
#   }
# }

#############################################################################
# VARIABLES
#############################################################################

# Variables:
# define a region 1 and region 2
# define vpc cidr ranges for region 1, cidr ranges for region 2
# Providers:
# create 2 instances of the aws provider. The differences are region and alias
# Data Sources
# previously we queried the availability zones for each region
# to know which availability zones to use for subnets
# specify a unique provider per each region to know which availability zones to query
# Modules
# specify resource name under providers
# and used varables for region for the database_subnets
# Output
# specify vpc_id for region 1 and region 2



variable "region_1" {
  type    = string
  default = "us-east-1"
}

variable "region_2" {
  type    = string
  default = "us-west-1"
}

variable "vpc_cidr_range_east" {
  type    = string
  default = "10.10.0.0/16"
}

variable "public_subnets_east" {
  type    = list(string)
  default = ["10.10.0.0/24", "10.10.1.0/24"]
}

variable "database_subnets_east" {
  type = list(string)
  default = ["10.10.8.0/24", "10.10.9.0/24"]
}

variable "vpc_cidr_range_west" {
  type    = string
  default = "10.11.0.0/16"
}

variable "public_subnets_west" {
  type    = list(string)
  default = ["10.11.0.0/24", "10.11.1.0/24"]
}

variable "database_subnets_west" {
  type = list(string)
  default = ["10.11.8.0/24", "10.11.9.0/24"]
}

#############################################################################
# PROVIDERS
#############################################################################

provider "aws" {
  version = "~> 2.0"
  region  = var.region_1
  alias = "east"
}

provider "aws" {
  version = "~> 2.0"
  region  = var.region_2
  alias = "west" # name of instance of provider, name label of provider
}

#############################################################################
# DATA SOURCES
#############################################################################

data "aws_availability_zones" "azs_east" {
    provider = aws.east
}

data "aws_availability_zones" "azs_west" {
    provider = aws.west
}

#############################################################################
# RESOURCES
#############################################################################

module "vpc_east" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.33.0"

  name = "prod-vpc-east"
  cidr = var.vpc_cidr_range_east

  azs            = slice(data.aws_availability_zones.azs_east.names, 0, 2)
  public_subnets = var.public_subnets_east

  # Database subnets
  database_subnets  = var.database_subnets_east
  database_subnet_group_tags = {
    subnet_type = "database"
  }

  providers = {
      aws = aws.east
  }

  tags = {
    Environment = "prod"
    Region = "east"
    Team        = "infra"
  }

}

module "vpc_west" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.33.0"

  name = "prod-vpc-west"
  cidr = var.vpc_cidr_range_west

  azs            = slice(data.aws_availability_zones.azs_west.names, 0, 2)
  public_subnets = var.public_subnets_west

  # Database subnets
  database_subnets  = var.database_subnets_west
  database_subnet_group_tags = {
    subnet_type = "database"
  }

  providers = {
      aws = aws.west
  }

  tags = {
    Environment = "prod"
    Region = "west"
    Team        = "infra"
  }

}

#############################################################################
# OUTPUTS
#############################################################################

output "vpc_id_east" {
  value = module.vpc_east.vpc_id
}

output "vpc_id_west" {
  value = module.vpc_west.vpc_id
}

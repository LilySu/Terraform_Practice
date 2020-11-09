# The terraform {} block is required so Terraform knows which provider
# to download from the Terraform Registry.

#aws provider's source is defined as hashicorp/aws which is shorthand
# for registry.terraform.io/hashicorp/aws.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.70" # prevent downloading a new provider that
      # may possibly contain breaking changes.
    }
  }
}
# The provider block configures the named provider, in our case aws,
# which is responsible for creating and managing resources. A provider
# is a plugin that Terraform uses to translate the API interactions
# with the service.
provider "aws" {
  profile = "default" # AWS credentials stored in your AWS Config
  #   File, which you created when you configured the AWS CLI.
  #   HashiCorp recommends that you never hard-code credentials into
  #   *.tf configuration files.
  region = var.region # tells terraform that you are accessing variables
}
# The resource block defines a piece of infrastructure. A resource
# might be a physical component such as an EC2 instance, or it
# can be a logical resource such as a Heroku application.

# The resource block has two strings before the block: the resource
# type and the resource name. In the example, the resource type is
# aws_instance and the name is example. The prefix of the type
# maps to the provider. In our case "aws_instance" automatically
# tells Terraform that it is managed by the "aws" provider.
resource "aws_instance" "example" {
  ami           = "ami-0817d428a6fb68645" # ami-098f16afa9edf40be
  instance_type = "t2.micro"
}

# The terraform fmt command automatically updates configurations
# in the current directory for easy readability and consistency.

# terraform validate command will check and report errors within
# modules, attribute names, and value types.

# Inspect the current state using terraform show

# setting variables in a variables.tf need to be executed:
# terraform apply -var "region=us-east-1"

# terraform.tfvars is for persistent variables
# items will be automatically loaded to populate variables

# if variables are in another .tf file, use:
# terraform apply -var-file="sensitive.tfvars"

# these variable files can be checked into version control or not
# multiple var files in such settings can be executed on the
# command line

# environment variables:
# export TF_VAR_region="us-east-1"
# unset TF_VAR_region

# - can only populate string type variables, list and maps must
# be done via another mechanism
# if variables are not specified, you will be prompted, but not recommended

# terraform cloud provides a user interface for setting up variables

# LISTS

# # Declare implicitly by using brackets []
# variable "cidrs" { default = [] }

# # Declare explicitly with 'list'
# variable "cidrs" { type = list }

# # You can specify list values in a terraform.tfvars file.
# cidrs = [ "10.0.0.0/16", "10.1.0.0/16" ]

# MAPS

# variable "amis" {
#   type = "map"
#   default = {
#     "us-east-1" = "ami-b374d5a5"
#     "us-west-2" = "ami-fc0b939c"
#   }
# }

# # A variable can be explicitly declared as a map type, or it can be
# # implicitly created by specifying a default value that is a map.
# # The above demonstrates both an explicit type = "map" and an
# # implicit default = {}.

# # To use the amis map, edit aws_instance to use var.amis keyed by var.region.
# resource "aws_instance" "example" {
#   ami           = var.amis[var.region]
#   instance_type = "t2.micro"
# }

# The square-bracket index notation used here is an example of how the
# map type expression is accessed as a variable, with [var.region]
# referencing the var.amis declaration for dynamic lookup.

# For a static value lookup, the region could be hard-coded such as var.amis["us-west-2"].

output "ip" {
  value = aws_eip.ip.public_ip
}

# Terraform supports team-based workflows with a feature known as remote
# backends. Remote backends allow Terraform to use a shared storage
# space for state data, so any member of your team can use Terraform to
# manage the same infrastructure.

# Terraform Cloud is the recommended best practice for remote state storage.

# A VCS-driven workflow, in which it automatically queues plans whenever
# changes are committed to your configuration's VCS repo.
# An API-driven workflow, in which a CI pipeline or other automated
# tool can upload configurations directly.

# # Configure Backend
# terraform {
#   backend "remote" {
#     organization = "<ORG_NAME>"

#     workspaces {
#       name = "Example-Workspace"
#     }
#   }
# }

# You'll also need a user token to authenticate with Terraform Cloud.

# Copy the user token to your clipboard, and create a Terraform CLI
# Configuration file. This file is located at %APPDATA%\terraform.rc
# on Windows systems, and ~/.terraformrc on other systems.

# credentials "app.terraform.io" {
#   token = "REPLACE_ME"
# }

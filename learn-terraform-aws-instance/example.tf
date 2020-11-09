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
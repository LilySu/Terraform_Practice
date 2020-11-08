# terraform configuration
#############################################################################
# VARIABLES
#############################################################################
# this is the unique values we recorded from the output of 3-sec-roles and 4-sec-vpc
# vpc id of the security vpc
variable "destination_vpc_id" {
  type = string
}

# creating roles and policies we got from 4-sec-vpc
variable "peer_role_arn" {
  type = string
}


#############################################################################
# PROVIDER
#############################################################################

provider "aws" {
  version = "~> 2.0"
  region  = var.region
  alias   = "peer" # distinguish from any other provider
  profile = "infra" # infra account
  # we assume a role that is from a different account
  # for this provider so we need the arn
  # we assume the role to accept the connection
  assume_role {
      role_arn = var.peer_role_arn # assume peering role so we can accept peering connection
  }

}

#############################################################################
# DATA SOURCES
#############################################################################
# caller identity for peer provider as we need account id again
data "aws_caller_identity" "peer" {
  provider = aws.peer
}

#############################################################################
# RESOURCES
#############################################################################

# Create the peering connection
# this is the infrastructure account
resource "aws_vpc_peering_connection" "peer" {
  vpc_id        = module.vpc.vpc_id # source dev vpc
  peer_vpc_id   = var.destination_vpc_id # vpc we want to peer with, the security vpc
  peer_owner_id = data.aws_caller_identity.peer.account_id
  peer_region   = var.region
  auto_accept   = false # not set to true because the aws_vpc_peering_connection_accepter handles this

}
# uses assumed role in security account by referencing aws.peer
resource "aws_vpc_peering_connection_accepter" "peer" {
  provider                  = aws.peer
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  auto_accept               = true # accept the connector using the assumed role

}

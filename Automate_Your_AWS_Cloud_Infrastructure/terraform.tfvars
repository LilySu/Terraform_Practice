# will assign variable for prompt
# terraform automatically looks for this file
# or could be name a unique file ie. in command line:
# terraform apply -var-file example.tfvars
subnet_prefix = "10.0.200.0/24"
# can be list of strings or list of objects
# ie. for list of objects:
# subnet_prefix = [{cidr_block = "10.0.200.0/24", name = "prod_subnet"}, {cidr_block = "10.0.2.0/24", name = "dev_subnet"}]
# resource "aws_subnet" "subnet-1" {
#     vpc_id = aws_vpc.prod-vpc.id
#     cidr_block = var.subnet_prefix[0].cidr_block
#     availability_zone = "us-east-1a"
#     tags = {
#         Name = var.subnet_prefix[0].name
#     }
# }
# resource "aws_subnet" "subnet-1" {
#     vpc_id = aws_vpc.prod-vpc.id
#     cidr_block = var.subnet_prefix[1].cidr_block
#     availability_zone = "us-east-1a"
#     tags = {
#         Name = var.subnet_prefix[0].name
#     }
# }
# Configure the AWS Provider
provider "aws" {
    region                = "us-east-1"
    access_key     =
    secret_key =
}

# Create an AMI that will start a machine whose root device is backed by
# an EBS volume populated from a snapshot. It is assumed that such a snapshot
# already exists with the id "snap-xxxxxxxx".
# resource "aws_instance" "my-first-server" {
#   ami           = "ami-0817d428a6fb68645"
#   instance_type = "t2.micro"
#   tags = {
#       Name = "ubuntu"
#   }

# }
# If we do 'terraform apply' we will not be adding another instance.
# Because we only specified one instance here.
# It would only refresh our state
# We define our infrastructure in Terraform

# # Create a vpc and a subnet within the vpc
# resource "aws_vpc" "first-vpc"{
#     cidr_block = "10.0.0.0/16"
#     tags = {
#         Name = "production"
#     }
# }

# resource "aws_subnet" "subnet-1" {
#     vpc_id = aws_vpc.first-vpc.id # gets id of previous vpc
#     cidr_block = "10.0.1.0/24"
#     tags = {
#         Name = "prod-subnet"
#     }
# }
# # terraform generally figures out the sequence in which to create things

# files
# a .terraform file gets created whenever a plugin is specified.
# all assets related to the plugin are stored there


# Create an EC2 instance
# Deploy on a custom vpc
# custom subnet
# assign a public ip address
# ssh to connect to it
# automatically set up a web server to handle web traffic

# 1. create vpc

resource "aws_vpc" "prod-vpc"{
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "production"
    }
}

# 2. create internet gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id

}
# 3. create custom route table

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0" # default route, sends all traffic wherever this route points
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod"
  }
}
# 4. create subnet

variable "subnet_prefix" {
    description = "cidr block for the subnet"
    # can assign default value like this:
    # default = "10.0.66.0/24"
    # type = string # any
}

resource "aws_subnet" "subnet-1" {
    vpc_id = aws_vpc.prod-vpc.id
    cidr_block = "10.0.1.0/24" # var.subnet_prefix # could be specified here
    # terraform can prompt you to enter a value
    availability_zone = "us-east-1a" # if you don't specify this, aws will pick a random one for you
}

# 5. associate subnet with route table

resource "aws_route_table_association" "a"{
    subnet_id = aws_subnet.subnet-1.id
    route_table_id = aws_route_table.prod-route-table.id
}
# 6. create security group to allow traffic for ports 22, 80, 443 # ssh to it, http, https
# really good to keep a security group that is open for the protocols you need

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress { # allow tcp traffic on port 443
    description = "HTTPS"
    from_port   = 443 # this allows for a range of ports
    to_port     = 443
    protocol    = "tcp" # or udp
    cidr_blocks = ["0.0.0.0/0"] # which subnets could reach this box ie only our computer or certain devices
  }

  ingress { # allow tcp traffic on port 443
    description = "HTTP"
    from_port   = 80 # this allows for a range of ports
    to_port     = 80
    protocol    = "tcp" # or udp
    cidr_blocks = ["0.0.0.0/0"] # which subnets could reach this box ie only our computer or certain devices
  }

  ingress { # allow tcp traffic on port 443
    description = "SSH"
    from_port   = 22 # this allows for a range of ports
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # which subnets could reach this box ie only our computer or certain devices
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # any prototcol
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# 7. create a network interface with an ip in the subet in step 4
# this assigns a private ip address to the host
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id] #specify and ip address

  # we skip attaching to a device even though we can attach to a device now
  # we will go to the provisioning section of the ec2 instance to specify this
}
# 8. assign an elastic ip to the network interface in step 7 # elastic ip is a public ip address
# Creating the elastic ip relies on the creation of the internet gateway
resource "aws_eip" "one" {
  vpc      = true
  network_interface = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}

# gets this property and prints it out on the console when we hit apply
output "server_public_ip" {
    value = aws_eip.one.public_ip # resource and public_ip property
}


# 9. create an ubuntu server and install/enable apache, assign ip address in step 7 to ubuntu server
resource "aws_instance" "web-server-instance" {
    ami = "ami-0817d428a6fb68645"
    instance_type = "t2.micro"
    availability_zone = "us-east-1a"
    key_name = "spark-cluster"

    network_interface {
      device_index = 0 # for any ec2 instance, we can specify an interface
      network_interface_id = aws_network_interface.web-server-nic.id
    }
    # on deployment of server, run a few commands on the server
    # so we can automatically install apache
    user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo your very first web server > /var/www/html/index.html'
                EOF

    tags = {
        Name = "web-server"
    }
}
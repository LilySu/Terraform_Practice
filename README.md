### Terraform Learning Repo

#### [Automate_Your_AWS_Cloud_Infrastructure](https://www.youtube.com/watch?v=SLB_c_ayRMo&ab_channel=freeCodeCamp.org)
2.5 Hour Youtube video that covers the following:
 - ⌨️ (0:20:51) Terraform Overview
 - ⌨️ (0:43:31) Modifying Resources
 - ⌨️ (0:50:30) Deleting Resources
 - ⌨️ (0:54:55) Referencing Resources
 - ⌨️ (1:04:47) Terraform Files
 - ⌨️ (1:09:45) Practice Project
 - ⌨️ (1:50:32) Terraform State Commands
 - ⌨️ (1:54:05) Terraform Output
 - ⌨️ (2:00:39) Target Resources
 - ⌨️ (2:03:46) Terraform Variables
 The project goes through how to:
 1. Create a vpc
 2. Create an internet gateway
 3. Create a custom route table
 4. Create a subnet
 5. Associate subnet with route table
 6. create a security group to allow ports 22, 80, 443
 7. Create a network interface with an ip in the subnet from step 4.
 8. Assign an elastic IP to the network interface from step 7
 9. Create an Ubuntu server and install and enable apache

#### [Implementing-Terraform-on-AWS](https://app.pluralsight.com/library/courses/implementing-terraform-aws)
3.5 Video and hands-on series that covers
- Creating multiple providers and best practices managing policies and permissions
- Remote state
- AWS CodeCommit and Code Pipeline to automate deployment
- Using data sources and cloud formation

#### [Get Started with Terraform on Hashicorp.com](https://learn.hashicorp.com/collections/terraform/aws-get-started)
- Creating a docker container locally
- Authenticate with AWS, create an EC2 instance
- Declaring variables, environment variables, .tfvars files, displaying outputs
- Storing remote state
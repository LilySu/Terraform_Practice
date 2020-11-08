terraform {
    backend "s3" {
        key = "networking/terraform.tfstate"
    }
}
# because we are using workspaces, the workspace name will be appended to this key
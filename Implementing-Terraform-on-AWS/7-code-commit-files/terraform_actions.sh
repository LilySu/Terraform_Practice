#!/bin/bash
set -e

# either create a workspace or select a workspace
# look at what is in the remote state data
# if there is an existing workspace, it'll use that
# if there is no workspace, it will create one
echo "*********** Create or select workspace"
if [ $(terraform workspace list | grep -c "$WORKSPACE_NAME") -eq 0 ] ; then
  echo "Create new workspace $WORKSPACE_NAME"
  terraform workspace new $WORKSPACE_NAME
else
  echo "Switch to workspace $WORKSPACE_NAME"
  terraform workspace select $WORKSPACE_NAME
fi

# checks to see what actions to perform
# make a directory to store plan

if [ $TF_ACTION = "PLAN" ]
then
  echo "Making directory"
  mkdir -p plans
fi

# check again if the $TF_ACTION is plan
# run terraform plan
# make a record from that plan by piping record to tf_output.txt
# we might want to check the plan before we approve it
# copy the vpc.tfplan to s3 bucket
# so we can retrieve the plan file when we run the apply process
if [ $TF_ACTION = "PLAN" ]
then
  echo "Running plan"
  terraform plan -out vpc.tfplan > tf_output.txt
  aws s3 cp vpc.tfplan s3://$TF_BUCKET/plans/$WORKSPACE_NAME-vpc.tfplan
fi

# if the $TF_ACTION is apply
# we will retrieve the plan file from the s3 bucket
# run that plan and save to tf_output.txt
if [ $TF_ACTION = "APPLY" ]
then
  echo "Running apply"
  aws s3 cp s3://$TF_BUCKET/plans/$WORKSPACE_NAME-vpc.tfplan vpc.tfplan
  terraform apply vpc.tfplan > tf_output.txt
fi

if [ $TF_ACTION = "DESTROY" ]
then
  echo "Running destroy"
  terraform destroy -auto-approve > tf_output.txt
fi
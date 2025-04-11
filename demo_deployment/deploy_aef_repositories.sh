#!/bin/bash
# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

new_repo_name=$1
project_id=$2
working_directory=$3
github_user_name=$4
aef_operator_email=$5
terraform_bucket='aef-'$project_id'-tfe'
escaped_project_id=$(echo "$project_id" | sed 's/-/\\-/g')

# Check if arguments are provided
if [ -z "$new_repo_name" ] || [ -z "$project_id" ] || [ -z "$working_directory" ] || [ -z "$github_user_name" ] || [ -z "$aef_operator_email" ] || [ -z "$terraform_bucket" ]; then
  echo "Usage: $0 <new_repo_name> <project_id> <working_directory> <github_user_name> <aef_operator_email> <terraform_bucket>"
  exit 1
fi

if [ ! -z "$(ls -A $working_directory)" ]; then
  echo "The provided working directory is not empty."
  read -r -p "Do you want to use it anyway? [y/N] " response
  case "$response" in
  [yY][eE][sS] | [yY])
    ;;
  *)
    exit 1
    ;;
  esac
fi

if [ ! -d "$working_directory" ] || [[ "${working_directory:0:1}" != "/" ]]; then
  echo "Directory '$working_directory' does not exist. Creating it."
  mkdir $working_directory
fi

gcloud firestore databases list --project=$project_id | grep -q "(default)"
if [[ $? -eq 0 ]]; then
  echo "(default) Firestore database exists. Delete it before installing the AEF."
  exit 1
fi

gcloud storage buckets create "gs://$terraform_bucket" \
  --project="$project_id" \
  --location="us-central1" \
  --uniform-bucket-level-access

bq mk --connection --connection_type=CLOUD_RESOURCE --project_id=$project_id --location="us-central1" "aef-sample-conn"

#Fork demo [Dataform repository](https://github.com/googlecloudplatform/aef-data-orchestration/blob/0c1a69e655e3435b978e6a68640db141e86b2685/workflow-definitions/demo_pipeline_cloud_workflows.json#L42)
echo "Forking sample Dataform repository ..."
cd $working_directory
git config --global user.email $aef_operator_email
git config --global user.name $aef_operator_email
# Check if gh is installed
if ! command -v gh &> /dev/null; then
  echo "gh is not installed. Installing..."

  # Install gh based on OS
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    if command -v apt &> /dev/null; then
      sudo apt install gh -y
    elif command -v dnf &> /dev/null; then
      sudo dnf install gh -y
    elif command -v pacman &> /dev/null; then
      sudo pacman -S gh --noconfirm
    else
      echo "Unsupported package manager. Please install gh manually."
      exit 1
    fi
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    if command -v brew &> /dev/null; then
      brew install gh
    else
      echo "Homebrew is not installed. Please install Homebrew first or install gh manually."
      exit 1
    fi
  elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    # Windows
    echo "Please install gh manually from https://cli.github.com/"
    exit 1
  else
    echo "Unsupported OS. Please install gh manually."
    exit 1
  fi
fi

gh auth login

# Create a new repository from the template
gh repo view "$new_repo_name" &> /dev/null
if [[ $? -eq 0 ]]; then
  echo "Repository $new_repo_name exists."
  exit 1
fi
gh repo create $new_repo_name --template "https://github.com/oscarpulido55/aef-sample-dataform-repo" --public
sleep 3
gh repo clone "$new_repo_name"

# Replace <PROJECT_ID> with the actual Project ID in dataform.json
cd $new_repo_name
escaped_project_id=$(echo "$project_id" | sed 's/-/\\-/g')

sed -i.bak "s/<PROJECT_ID>/$escaped_project_id/g" dataform.json

# Commit the changes
git add dataform.json
git commit -m "Update dataform.json with Project ID"
git push origin main

cd $working_directory
if [ ! -f "aef-data-model/sample-data/terraform/tfplansampledata" ]; then
  echo "Deploying demo data sources aef-data-model/sample-data ... "
  gh repo fork googlecloudplatform/aef-data-model --clone
  cd aef-data-model/sample-data/terraform/
  terraform_prefix=$(echo "sample-data/environments/dev" | sed 's/\//\\\//g')
  sed -i.bak "s/<TERRAFORM_BUCKET>/$terraform_bucket/g" backend.tf
  sed -i.bak "s/<TERRAFORM_ENV>/$terraform_prefix/g" backend.tf
  sed -i.bak "s/<PROJECT_ID>/$escaped_project_id/g" demo.tfvars
  github_dataform_repository="https://github.com/$github_user_name/$new_repo_name.git"
  escaped_github_dataform_repository=$(echo "$github_dataform_repository" | sed 's/-/\\-/g')
  sed -i.bak "s|<GITHUB_DATAFORM_REPOSITORY>|$escaped_github_dataform_repository|g" demo.tfvars
  terraform init
  terraform plan -out=tfplansampledata -var-file="demo.tfvars"
  terraform apply -auto-approve tfplansampledata
  fake_onprem_sql_private_ip=$(terraform output fake_onprem_sql_ip)
else
  echo "WARNING!: There is a previous terraform deployment in aef-data-model/sample-data."
  read -r -p "Do you want to skip it and continue? [y/N] " response
  case "$response" in
  [yY][eE][sS] | [yY])
    ;;
  *)
    exit 1
    ;;
  esac
fi

cd $working_directory
if [ ! -f "aef-data-model/terraform/tfplandatamodel" ]; then
  echo "Deploying aef-data-model repository... "
  cd aef-data-model/terraform/
  terraform_prefix=$(echo "aef-data-model/environments/dev" | sed 's/\//\\\//g')
  sed -i.bak "s/<TERRAFORM_BUCKET>/$terraform_bucket/g" backend.tf
  sed -i.bak "s/<TERRAFORM_ENV>/$terraform_prefix/g" backend.tf
  sed -i.bak "s/<PROJECT_ID>/$escaped_project_id/g" prod.tfvars
  sed -i.bak "s|<GITHUB_DATAFORM_REPOSITORY>|$escaped_github_dataform_repository|g" prod.tfvars
  terraform init
  terraform plan -out=tfplandatamodel -var-file="prod.tfvars"
  terraform apply -auto-approve tfplandatamodel
else
  echo "WARNING!: There is a previous terraform deployment in aef-data-model."
  read -r -p "Do you want to skip it and continue? [y/N] " response
  case "$response" in
  [yY][eE][sS] | [yY])
    ;;
  *)
    exit 1
    ;;
  esac
fi

cd $working_directory
if [ ! -f "aef-data-orchestration/terraform/tfplandataorch" ]; then
  echo "Deploying aef-data-orchestration repository... "
  gh repo fork googlecloudplatform/aef-data-orchestration --clone
  cd aef-data-orchestration/terraform
  terraform_prefix=$(echo "aef-data-orchestration/environments/dev" | sed 's/\//\\\//g')
  sed -i.bak "s/<TERRAFORM_BUCKET>/$terraform_bucket/g" backend.tf
  sed -i.bak "s/<TERRAFORM_ENV>/$terraform_prefix/g" backend.tf
  sed -i.bak "s/<PROJECT_ID>/$escaped_project_id/g" prod.tfvars
  terraform init
  terraform plan -out=tfplandataorch -var-file="prod.tfvars"
  terraform apply -auto-approve tfplandataorch
  terraform plan -out=tfplandataorch -var-file="prod.tfvars"
  terraform apply -auto-approve tfplandataorch
else
  echo "WARNING!: There is a previous terraform deployment in aef-data-orchestration."
  read -r -p "Do you want to skip it and continue? [y/N] " response
  case "$response" in
  [yY][eE][sS] | [yY])
    ;;
  *)
    exit 1
    ;;
  esac
fi

cd $working_directory
if [ ! -f "aef-data-transformation/terraform/tfplandatatrans" ]; then
  gh repo fork googlecloudplatform/aef-data-transformation --clone
  sed -i.bak "s/<PROJECT_ID>/$escaped_project_id/g" aef-data-transformation/jobs/dev/dataflow-flextemplate-job-executor/sample_jdbc_dataflow_ingestion.json
  gcloud config set project $project_id
  fake_onprem_sql_private_ip=$(gcloud sql instances describe fake-on-prem-instance --format="value(ipAddresses[2].ipAddress)")
  sed -i.bak "s/<DB_PRIVATE_IP>/$fake_onprem_sql_private_ip/g" aef-data-transformation/jobs/dev/dataflow-flextemplate-job-executor/sample_jdbc_dataflow_ingestion.json
  sed -i.bak "s/<PROJECT_ID>/$escaped_project_id/g" aef-data-transformation/jobs/dev/dataform-tag-executor/run_dataform_tag.json
  sed -i.bak "s/<PROJECT_ID>/$escaped_project_id/g" aef-data-transformation/jobs/dev/dataproc-serverless-job-executor/sample_serverless_spark_mainframe_ingestion.json
  sed -i.bak "s/<PROJECT_ID>/$escaped_project_id/g" aef-data-transformation/jobs/dev/dataproc-serverless-job-executor/cobrix/example_cobrix_job.json
  cd aef-data-transformation/terraform
  terraform_prefix=$(echo "aef-data-transformation/environments/dev" | sed 's/\//\\\//g')
  sed -i.bak "s/<TERRAFORM_BUCKET>/$terraform_bucket/g" backend.tf
  sed -i.bak "s/<TERRAFORM_ENV>/$terraform_prefix/g" backend.tf
  terraform init
  terraform plan -out=tfplandatatrans -var "project=$project_id" -var 'region=us-central1' -var 'domain=example' -var 'environment=dev'
  terraform apply -auto-approve tfplandatatrans
  terraform plan -out=tfplandatatrans -var "project=$project_id" -var 'region=us-central1' -var 'domain=example' -var 'environment=dev'
  terraform apply -auto-approve tfplandatatrans
else
  echo "WARNING!: There is a previous terraform deployment in aef-data-transformation."
  read -r -p "Do you want to skip it and continue? [y/N] " response
  case "$response" in
  [yY][eE][sS] | [yY])
    ;;
  *)
    exit 1
    ;;
  esac
fi

cd $working_directory
if [ ! -f "aef-orchestration-framework/terraform/tfplanorchframework" ]; then
  gh repo fork googlecloudplatform/aef-orchestration-framework --clone
  cd aef-orchestration-framework/terraform
  terraform_prefix=$(echo "aef-orchestration-framework/environments/dev" | sed 's/\//\\\//g')
  sed -i.bak "s/<TERRAFORM_BUCKET>/$terraform_bucket/g" backend.tf
  sed -i.bak "s/<TERRAFORM_ENV>/$terraform_prefix/g" backend.tf
  terraform init
  terraform plan -out=tfplanorchframework -var "project=$project_id" -var "region=us-central1" -var "operator_email=$aef_operator_email"
  terraform apply -auto-approve tfplanorchframework
  #Propagation Delay - Eventarc API enabled for the first time in a project, Eventarc Service Agent is created
  #Wait for 5-15
  terraform plan -out=tfplanorchframework -var "project=$project_id" -var "region=us-central1" -var "operator_email=$aef_operator_email"
  terraform apply -auto-approve tfplanorchframework
else
  echo "WARNING!: There is a previous terraform deployment in aef-orchestration-framework, skipping it ... "
fi

bq rm --connection -f "$project_id.us-central1.aef-sample-conn"
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
#   Required Google Cloud APIs:
#   - BigQuery Connection API
#   - BigQuery Data Policy API
#   - Dataform API
#   - Error Reporting API
#   - —
#  - Compute Engine API
#   - Service Networking API
#   - —
#   - Secret Manager API
#   - —
#   - Google Cloud Firestore API
#   - Cloud Functions API
#   - Cloud Run Admin API
#   - Cloud Build API
#   - Eventarc API
#   - Workflows API
#   - —
#   - Cloud Scheduler API
#   - Dataflow API
#   - Error Reporting API
#   - Cloud Dataproc API
#   - Cloud Composer
#   - Cloud Data Lineage

gcloud config set project $1
gcloud services enable bigquery.googleapis.com \
                       bigquerydatapolicy.googleapis.com \
                       bigqueryconnection.googleapis.com \
                       cloudbuild.googleapis.com \
                       storage-component.googleapis.com \
                       cloudresourcemanager.googleapis.com \
                       dataflow.googleapis.com \
                       dataform.googleapis.com \
                       clouderrorreporting.googleapis.com \
                       compute.googleapis.com \
                       servicenetworking.googleapis.com \
                       secretmanager.googleapis.com \
                       firestore.googleapis.com \
                       cloudfunctions.googleapis.com \
                       run.googleapis.com \
                       eventarc.googleapis.com \
                       workflows.googleapis.com \
                       cloudscheduler.googleapis.com \
                       datacatalog.googleapis.com

gcloud services enable bigquery.googleapis.com \
                       dataproc.googleapis.com \
                       composer.googleapis.com \
                       datalineage.googleapis.com \
                       clouderrorreporting.googleapis.com \
                       orgpolicy.googleapis.com \
                       container.googleapis.com \
                       containerregistry.googleapis.com \
                       storage.googleapis.com \
                       metastore.googleapis.com


#sample BQ connection to warm-up and trigger default service agent creation (known issue)
bq mk --connection --connection_type=CLOUD_RESOURCE --project_id=$project_id --location="us-central1" "aef-sample-conn"

#Relax require OS Login (Argolis needed)
rm os_login.yaml
cat > os_login.yaml << ENDOFFILE
name: projects/$project_id/policies/compute.requireOsLogin
spec:
  rules:
  - enforce: false
ENDOFFILE
gcloud org-policies set-policy os_login.yaml
rm os_login.yaml

#Disable Serial Port Logging (Argolis needed)
rm disableSerialPortLogging.yaml
cat > disableSerialPortLogging.yaml << ENDOFFILE
name: projects/$project_id/policies/compute.disableSerialPortLogging
spec:
  rules:
  - enforce: false
ENDOFFILE
gcloud org-policies set-policy disableSerialPortLogging.yaml
rm disableSerialPortLogging.yaml

#Disable Shielded VM requirement (Argolis needed)
rm shieldedVm.yaml
cat > shieldedVm.yaml << ENDOFFILE
name: projects/$project_id/policies/compute.requireShieldedVm
spec:
  rules:
  - enforce: false
ENDOFFILE
gcloud org-policies set-policy shieldedVm.yaml
rm shieldedVm.yaml

#Disable VM can IP forward requirement (Argolis needed)
rm vmCanIpForward.yaml
cat > vmCanIpForward.yaml << ENDOFFILE
name: projects/$project_id/policies/compute.vmCanIpForward
spec:
  rules:
  - allowAll: true
ENDOFFILE
gcloud org-policies set-policy vmCanIpForward.yaml
rm vmCanIpForward.yaml

#Enable VM external access (Argolis needed)
rm vmExternalIpAccess.yaml
cat > vmExternalIpAccess.yaml << ENDOFFILE
name: projects/$project_id/policies/compute.vmExternalIpAccess
spec:
  rules:
  - allowAll: true
ENDOFFILE
gcloud org-policies set-policy vmExternalIpAccess.yaml
rm vmExternalIpAccess.yaml

#Enable restrict VPC peering (Argolis needed)
rm restrictVpcPeering.yaml
cat > restrictVpcPeering.yaml << ENDOFFILE
name: projects/$project_id/policies/compute.restrictVpcPeering
spec:
  rules:
  - allowAll: true
ENDOFFILE
gcloud org-policies set-policy restrictVpcPeering.yaml
rm restrictVpcPeering.yaml
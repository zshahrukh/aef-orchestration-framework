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

project_id=$1
gcloud config set project $project_id
#https://github.com/anagha-google/spark-on-gcp-s8s/blob/main/01-foundational-setup.md#0-prerequisites

#Relax require OS Login (Argolis needed)
cat > os_login.yaml << ENDOFFILE
name: projects/$project_id/policies/compute.requireOsLogin
spec:
  rules:
  - enforce: false
ENDOFFILE
gcloud org-policies set-policy os_login.yaml
rm os_login.yaml

#Disable Serial Port Logging (Argolis needed)
cat > disableSerialPortLogging.yaml << ENDOFFILE
name: projects/$project_id/policies/compute.disableSerialPortLogging
spec:
  rules:
  - enforce: false
ENDOFFILE
gcloud org-policies set-policy disableSerialPortLogging.yaml
rm disableSerialPortLogging.yaml

#Disable Shielded VM requirement (Argolis needed)
cat > shieldedVm.yaml << ENDOFFILE
name: projects/$project_id/policies/compute.requireShieldedVm
spec:
  rules:
  - enforce: false
ENDOFFILE
gcloud org-policies set-policy shieldedVm.yaml
rm shieldedVm.yaml

#Disable VM can IP forward requirement (Argolis needed)
cat > vmCanIpForward.yaml << ENDOFFILE
name: projects/$project_id/policies/compute.vmCanIpForward
spec:
  rules:
  - allowAll: true
ENDOFFILE
gcloud org-policies set-policy vmCanIpForward.yaml
rm vmCanIpForward.yaml

#Enable VM external access (Argolis needed)
cat > vmExternalIpAccess.yaml << ENDOFFILE
name: projects/$project_id/policies/compute.vmExternalIpAccess
spec:
  rules:
  - allowAll: true
ENDOFFILE
gcloud org-policies set-policy vmExternalIpAccess.yaml
rm vmExternalIpAccess.yaml

#Enable restrict VPC peering (Argolis needed)
cat > restrictVpcPeering.yaml << ENDOFFILE
name: projects/$project_id/policies/compute.restrictVpcPeering
spec:
  rules:
  - allowAll: true
ENDOFFILE
gcloud org-policies set-policy restrictVpcPeering.yaml
rm restrictVpcPeering.yaml

# --- Create Policy YAML ---
# Using the same structure as your osLogin example.
# This attempts to disable enforcement for this specific policy
# directly on the specified project.
cat > external_ip_policy_simple.yaml << ENDOFFILE
name: projects/$project_id/policies/compute.vmExternalIpAccess
spec:
  inheritFromParent: false
  rules:
  - allowAll: true
ENDOFFILE
gcloud org-policies set-policy external_ip_policy_simple.yaml
rm external_ip_policy_simple.yaml

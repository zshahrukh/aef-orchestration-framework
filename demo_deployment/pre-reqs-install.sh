#!/bin/bash

# Simple script to check for and install common tools in Google Cloud Shell.

echo "Starting AEF Tool Check & Installation Script..."
echo "---"

# Helper function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

echo "Checking for Git..."
if command_exists git; then
  echo "[OK] Git is already available."
else
  echo "[INFO] Git not found. Attempting installation via apt..."
  sudo apt-get update && sudo apt-get install -y git
  if command_exists git; then
    echo "[OK] Git installed successfully."
  else
    echo "[FAIL] Git installation failed."
  fi
fi

echo "Checking for GitHub CLI (gh)..."
if command_exists gh; then
  echo "[OK] GitHub CLI (gh) is already available."
else
  echo "[INFO] GitHub CLI (gh) not found. Attempting installation..."
  echo "[SETUP] Ensuring dependencies (curl, gpg)..."
  sudo apt-get update > /dev/null && sudo apt-get install -y curl gpg software-properties-common apt-transport-https ca-certificates
  if ! command_exists curl || ! command_exists gpg; then
      echo "[FAIL] Failed to ensure curl/gpg are installed. Cannot add repository for gh."
  else
      echo "[SETUP] Downloading GitHub CLI GPG Key..."
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg

      if [ $? -ne 0 ]; then
          echo "[FAIL] Failed to download GPG key for gh."
      else
          sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
          echo "[SETUP] Adding gh apt repository..."
          echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
          echo "[INSTALLING] Updating apt list and installing gh..."
          sudo apt-get update && sudo apt-get install -y gh
          if command_exists gh; then
              echo "[OK] GitHub CLI (gh) installed successfully."
          else
              echo "[FAIL] GitHub CLI (gh) installation failed. Check logs above."
          fi
      fi
  fi
fi

echo "Checking for Python 3 (python3 command)..."
if command_exists python3; then
  echo "[OK] Python 3 is already available."
  if ! command_exists pip3; then
    echo "[INFO] pip3 not found. Installing python3-pip..."
    sudo apt-get update && sudo apt-get install -y python3-pip
    if command_exists pip3; then
        echo "[OK] pip3 installed."
    else
        echo "[WARN] Failed to install pip3."
    fi
  else
    echo "[OK] pip3 is also available."
  fi
else
  echo "[INFO] Python 3 not found. Attempting installation via apt..."
  sudo apt-get update && sudo apt-get install -y python3 python3-pip
  if command_exists python3; then
    echo "[OK] Python 3 installed successfully."
    command_exists pip3 || echo "[WARN] pip3 check failed after Python 3 install."
  else
    echo "[FAIL] Python 3 installation failed."
  fi
fi

echo "Checking for Terraform..."
if command_exists terraform; then
  echo "[OK] Terraform is already available."
  if terraform version | grep -Eq "^Terraform v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*) " | grep -Eq "v(0|1)\.(0|[1-9][0-9]*|[1-9][0-9]*\.[0-9]+|[1-9][0-9]*\.[0-9]+\.[0-9]+|1\.(0|[1-9][0-9]*|[1-9][0-9]*\.[0-9]+|[1-9][0-9]*\.[0-9]+\.[0-9]+)|1\.10\.(2|[3-9][0-9]*|[1-9][0-9]*\.[0-9]+|[1-9][0-9]*\.[0-9]+\.[0-9]+)|1\.[1-9][1-9]*\.(0|[1-9][0-9]*|[1-9][0-9]*\.[0-9]+|[1-9][0-9]*\.[0-9]+\.[0-9]+))"; then
    echo "Terraform version is >= 1.10.2"
  else
    echo "Terraform version is < 1.10.2 Upgrading Terraform."
    sudo rm /usr/share/keyrings/hashicorp-archive-keyring.gpg
    wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install terraform
  fi
else
  echo "[INFO] Terraform not found. Attempting installation..."
  # Ensure dependencies: curl, unzip are needed
  echo "[SETUP] Checking/installing dependencies (curl, unzip)..."
  sudo apt-get update > /dev/null # Update quietly
  # Check and install curl if missing
  command_exists curl || sudo apt-get install -y curl
  # Check and install unzip if missing
  command_exists unzip || sudo apt-get install -y unzip

  # Verify dependencies are present now
  if ! command_exists curl || ! command_exists unzip; then
      echo "[FAIL] Failed to install required dependencies (curl/unzip). Cannot install Terraform automatically."
      echo "[INFO] Please install manually from: https://developer.hashicorp.com/terraform/install"
  else
      echo "[SETUP] Dependencies OK."
      echo "[FETCH] Finding latest Terraform version (amd64 Linux)..."
      TERRAFORM_LATEST_URL=$(curl -sL https://releases.hashicorp.com/terraform/ | grep -Eo '/terraform/[0-9]+\.[0-9]+\.[0-9]+/terraform_[0-9]+\.[0-9]+\.[0-9]+_linux_amd64.zip' | head -n1)

      if [ -z "$TERRAFORM_LATEST_URL" ]; then
          echo "[FAIL] Could not automatically find the latest Terraform download URL via simple grep."
          echo "[INFO] Please install manually from: https://developer.hashicorp.com/terraform/install"
      else
          FULL_URL="https://releases.hashicorp.com${TERRAFORM_LATEST_URL}"
          FILENAME=$(basename "$FULL_URL")
          echo "[DOWNLOAD] Downloading $FILENAME..."
          # Use curl -f to fail silently on server errors, check exit code $?
          curl -fsLo "$FILENAME" "$FULL_URL"

          if [ $? -ne 0 ]; then
              echo "[FAIL] Download failed. Check URL or network."
              rm -f "$FILENAME" # Clean up potentially partial file
          else
              echo "[UNZIP] Extracting Terraform..."
              # Unzip just the terraform binary (-j junk paths) to current dir
              unzip -oj "$FILENAME" terraform -d .

              if [ $? -ne 0 ]; then
                  echo "[FAIL] Unzip failed. The archive might be corrupted."
              elif [ ! -f "terraform" ]; then
                  echo "[FAIL] 'terraform' executable not found after unzip."
              else
                  echo "[INSTALL] Moving terraform binary to /usr/local/bin/..."
                  sudo mv terraform /usr/local/bin/
                  if [ $? -ne 0 ]; then
                      echo "[FAIL] Failed to move terraform to /usr/local/bin/. Check permissions."
                      rm -f terraform # Clean up extracted binary if move failed
                  else
                      # Set executable permission (good practice)
                      sudo chmod +x /usr/local/bin/terraform
                      echo "[OK] Terraform installed successfully."
                  fi
              fi
              # Clean up archive regardless of move success/failure
              echo "[CLEANUP] Removing $FILENAME..."
              rm -f "$FILENAME"
          fi
      fi
  fi
fi
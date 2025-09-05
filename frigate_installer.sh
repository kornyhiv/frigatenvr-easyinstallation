#!/bin/bash

# Color definitions for professional output using ANSI C quoting for reliability
COLOR_RESET=$'\e[0m'
COLOR_BOLD=$'\e[1m'
COLOR_GREEN=$'\e[32m'
COLOR_YELLOW=$'\e[33m'
COLOR_RED=$'\e[31m'
COLOR_HEADER=$'\e[1;33m'  # Bold yellow for headers
COLOR_INFO=$'\e[32m'      # Green for info
COLOR_SUCCESS=$'\e[1;32m' # Bold green for success
COLOR_WARN=$'\e[33m'      # Yellow for warnings
COLOR_PROMPT=$'\e[33m'     # Yellow for prompts
COLOR_ERROR=$'\e[31m'      # Red for errors

# Function for section headers
section_header() {
  echo -e "\n${COLOR_HEADER}================================================================================${COLOR_RESET}" >&2
  echo -e "${COLOR_HEADER} $1 ${COLOR_RESET}" >&2
  echo -e "${COLOR_HEADER}================================================================================${COLOR_RESET}\n" >&2
}

# Function for success messages
success_msg() {
  echo -e "${COLOR_SUCCESS}[SUCCESS] $1${COLOR_RESET}" >&2
}

# Function for info messages
info_msg() {
  echo -e "${COLOR_INFO}[INFO] $1${COLOR_RESET}" >&2
}

# Function for warning messages
warn_msg() {
  echo -e "${COLOR_WARN}[WARNING] $1${COLOR_RESET}" >&2
}

# Function for error messages
error_msg() {
  echo -e "${COLOR_ERROR}[ERROR] $1${COLOR_RESET}" >&2
}

# ASCII art for Easy Installation
echo -e "${COLOR_GREEN}
  ______           _______     __  _____ _   _  _____ _______       _      _            _______ _____ ____  _   _ 
 |  ____|   /\    / ____\ \   / / |_   _| \ | |/ ____|__   __|/\   | |    | |        /\|__   __|_   _/ __ \| \ | |
 | |__     /  \  | (___  \ \_/ /    | | |  \| | (___    | |  /  \  | |    | |       /  \  | |    | || |  | |  \| |
 |  __|   / /\ \  \___ \  \   /     | | | . ` |\___ \   | | / /\ \ | |    | |      / /\ \ | |    | || |  | | . ` |
 | |____ / ____ \ ____) |  | |     _| |_| |\  |____) |  | |/ ____ \| |____| |____ / ____ \| |   _| || |__| | |\  |
 |______/_/    \_\_____/   |_|    |_____|_| \_|_____/   |_/_/    \_\______|______/_/    \_\_|  |_____\____/|_| \_|
                                                                                                                  
                                                                                                                  
${COLOR_RESET}" >&2

SETTINGS_FILE="./frigate_installation_settings"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Function to prompt user for folder path
prompt_for_folder() {
  local folder_type="$1"
  local prompt_message="$2"
  read -p "${COLOR_PROMPT}${prompt_message}${COLOR_RESET}" folder_path >&2
  if [ -z "$folder_path" ]; then
    error_msg "Path cannot be empty. Exiting."
    exit 1
  fi
  if [[ ! "$folder_path" = /* ]]; then
    folder_path="$SCRIPT_DIR/$folder_path"
    info_msg "Relative path detected, using absolute path: $folder_path"
  fi
  if [ ! -d "$folder_path" ]; then
    info_msg "Creating folder: $folder_path"
    mkdir -p "$folder_path" || { error_msg "Error creating folder $folder_path. Check permissions."; exit 1; }
  fi
  echo "$folder_path"
}

# Function to stop Frigate container
stop_frigate_container() {
  section_header "Stopping Frigate Container"
  info_msg "Stopping Frigate container..."
  docker stop frigate &>/dev/null
  success_msg "Frigate container stopped."
}

# Function to delete Frigate installation
delete_frigate_installation() {
  section_header "Deleting Frigate Installation"
  info_msg "Stopping and deleting Frigate containers..."
  docker stop frigate &>/dev/null
  docker rm -f $(docker ps -a -q -f name=frigate) &>/dev/null
  rm -f "$SETTINGS_FILE"
  success_msg "Deleted Frigate installation and configuration file: $SETTINGS_FILE"

  # Optionally delete config and media folders - ask user first
  read -p "${COLOR_PROMPT}Do you want to delete the configuration folder ($CONFIG_FOLDER)? (yes/no): ${COLOR_RESET}" delete_config
  if [[ "$delete_config" == "yes" ]] && [ -d "$CONFIG_FOLDER" ]; then
    rm -rf "$CONFIG_FOLDER"
    success_msg "Deleted config folder: $CONFIG_FOLDER"
  fi

  if [ -n "$MEDIA_FOLDER" ]; then
    read -p "${COLOR_PROMPT}Do you want to delete the media folder ($MEDIA_FOLDER)? THIS WILL DELETE RECORDINGS. (yes/no): ${COLOR_RESET}" delete_media
    if [[ "$delete_media" == "yes" ]] && [ -d "$MEDIA_FOLDER" ]; then
      rm -rf "$MEDIA_FOLDER"
      success_msg "Deleted media folder: $MEDIA_FOLDER"
    fi
  fi

  success_msg "Frigate installation deleted."
}

# Function to check if Docker and Buildx are installed correctly
check_docker() {
  section_header "Checking Docker and Buildx Installation"
  if docker buildx version &>/dev/null; then
    success_msg "Docker and Docker Buildx are already installed."
  else
    warn_msg "Docker or Docker Buildx not found/not working."
    info_msg "Setting up official Docker repository and installing components..."

    # Uninstall old versions
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove -y $pkg; done

    # Add Docker's official GPG key:
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update

    # Install the latest version
    info_msg "Installing Docker CE, CLI, Containerd, and Buildx plugin..."
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    if [ $? -ne 0 ]; then
        error_msg "Failed to install Docker components from the official repository. Please check for errors."
        exit 1
    fi

    # Add user to docker group
    sudo usermod -aG docker "$USER" || warn_msg "Could not add user to docker group. You may need to run docker commands with sudo."

    success_msg "Docker and Buildx installed successfully from the official repository."
    info_msg "If you were not already in the 'docker' group, you need to log out and log back in to apply the changes."
  fi
}

# Function to check if dependencies (curl and jq) are installed
check_dependencies() {
  section_header "Checking Dependencies"
  if ! command -v curl &>/dev/null || ! command -v jq &>/dev/null; then
    info_msg "Dependencies not found. Installing curl and jq..."
    sudo apt-get update
    sudo apt-get install -y curl jq
    success_msg "Dependencies installed successfully."
  else
    success_msg "Dependencies (curl and jq) are already installed."
  fi
}

# Function to ensure the Docker daemon is running
ensure_docker_running() {
  section_header "Ensuring Docker Service is Active"
  if ! systemctl is-active --quiet docker; then
    warn_msg "Docker service is not running. Attempting to start it..."
    sudo systemctl start docker
    # Wait a few seconds to let the daemon initialize
    sleep 5
    if ! systemctl is-active --quiet docker; then
      error_msg "Failed to start Docker service. Please run 'sudo systemctl status docker.service' and 'sudo journalctl -xeu docker.service' to diagnose the issue."
      exit 1
    fi
    success_msg "Docker service is now running."
  else
    success_msg "Docker service is already active."
  fi
}

# Function to install NVIDIA dependencies
install_nvidia_dependencies() {
  section_header "Installing NVIDIA Dependencies"
  info_msg "Checking for NVIDIA GPU..."
  if ! lspci | grep -i nvidia; then
    warn_msg "No NVIDIA GPU detected."
    read -p "${COLOR_PROMPT}Do you want to proceed anyway? (y/n): ${COLOR_RESET}" proceed
    if [ "$proceed" != "y" ]; then
      error_msg "Exiting installation."
      exit 1
    fi
  else
    success_msg "NVIDIA GPU detected."
  fi

  # Set CUDA paths if installed
  if [ -d /usr/local/cuda/bin ]; then
    export PATH=/usr/local/cuda/bin:$PATH
    export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
    info_msg "CUDA paths set."
  fi

  # Check if NVIDIA drivers are installed and loaded
  nvidia-smi > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    success_msg "NVIDIA drivers already installed and loaded. Skipping driver installation."
  else
    info_msg "Installing NVIDIA drivers..."
    sudo apt update && sudo ubuntu-drivers autoinstall
    if [ $? -ne 0 ]; then
      error_msg "Error installing NVIDIA drivers. Exiting."
      exit 1
    fi

    info_msg "Checking if NVIDIA driver is loaded..."
    nvidia-smi > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      warn_msg "NVIDIA driver installed but not loaded. A reboot is required."
      read -p "${COLOR_PROMPT}Do you want to reboot now? (yes/no): ${COLOR_RESET}" reboot_now
      if [ "$reboot_now" = "yes" ]; then
        sudo reboot
        exit 0
      else
        info_msg "Please reboot the system and run the script again to continue."
        exit 0
      fi
    fi
    success_msg "NVIDIA drivers installed and loaded."
  fi

  # Check if CUDA Toolkit is installed
  if [ -f /usr/local/cuda/bin/nvcc ]; then
    success_msg "CUDA Toolkit already installed. Skipping."
  else
    info_msg "Installing CUDA Toolkit..."
    DISTRO=ubuntu$(lsb_release -rs | tr -d .)
    ARCH=x86_64
    wget https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}/${ARCH}/cuda-keyring_1.1-1_all.deb
    sudo dpkg -i cuda-keyring_1.1-1_all.deb
    sudo apt update
    sudo apt install -y cuda-toolkit
    if [ $? -ne 0 ]; then
      error_msg "Error installing CUDA Toolkit. Exiting."
      exit 1
    fi
    success_msg "CUDA Toolkit installed."

    # Immediately export paths after installation
    export PATH=/usr/local/cuda/bin:$PATH
    export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
    info_msg "CUDA paths exported for current session."
  fi

  # Check if NVIDIA Container Toolkit is installed
  if command -v nvidia-ctk &>/dev/null; then
    success_msg "NVIDIA Container Toolkit already installed. Skipping."
  else
    info_msg "Installing NVIDIA Container Toolkit..."
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    sudo apt update
    sudo apt install -y nvidia-container-toolkit
    if [ $? -ne 0 ]; then
      error_msg "Error installing NVIDIA Container Toolkit. Exiting."
      exit 1
    fi
    success_msg "NVIDIA Container Toolkit installed."
  fi

  info_msg "Generating CDI configuration..."
  sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
  sudo systemctl restart docker

  section_header "Verifying NVIDIA Setup"
  info_msg "Running nvidia-smi:"
  nvidia-smi || { error_msg "nvidia-smi failed. Please check NVIDIA drivers and GPU. May require reboot."; exit 1; }

  # Ensure paths are set before nvcc check
  if ! command -v nvcc &>/dev/null; then
    info_msg "nvcc not found initially. Retrying after path export..."
    export PATH=/usr/local/cuda/bin:$PATH
    export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
    sleep 5  # Brief delay for any post-install settling
  fi

  info_msg "Running nvcc --version:"
  if ! nvcc --version; then
    error_msg "nvcc not found even after path export. Please check CUDA installation."
    exit 1
  fi
  success_msg "NVIDIA dependencies installed successfully."
  info_msg "If a reboot was required, please reboot and run the script again."

  # Append CUDA paths to user's ~/.bashrc if not already present
  USER_BASHRC="/home/$SUDO_USER/.bashrc"
  if [ -f "$USER_BASHRC" ] && ! grep -q "export PATH=/usr/local/cuda/bin:\$PATH" "$USER_BASHRC"; then
    echo "export PATH=/usr/local/cuda/bin:\$PATH" >> "$USER_BASHRC"
    echo "export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\$LD_LIBRARY_PATH" >> "$USER_BASHRC"
    success_msg "Appended CUDA environment variables to $USER_BASHRC."
    source "$USER_BASHRC"  # Source immediately to apply in current session
    info_msg "Sourced $USER_BASHRC for current session."
  else
    success_msg "CUDA environment variables already present in $USER_BASHRC."
  fi
}

# Function to load configuration from file if it exists
load_configuration() {
  if [ -f "$SETTINGS_FILE" ]; then
    source "$SETTINGS_FILE"
    info_msg "Loaded configuration from $SETTINGS_FILE."
  fi
}

# Function to get storage type
get_storage_type() {
    load_configuration
    if [ -z "$USE_USB_DRIVE" ]; then
        section_header "Configuring Storage Type"
        read -p "${COLOR_PROMPT}Will an external USB drive be used for the storage media folder? (yes/no): ${COLOR_RESET}" use_usb
        case "$use_usb" in
            yes)
                USE_USB_DRIVE=true
                ;;
            no)
                USE_USB_DRIVE=false
                ;;
            *)
                error_msg "Invalid option. Exiting."
                exit 1
                ;;
        esac
        sed -i "/^USE_USB_DRIVE=/d" "$SETTINGS_FILE"
        echo "USE_USB_DRIVE=\"$USE_USB_DRIVE\"" >> "$SETTINGS_FILE"
        success_msg "External USB drive usage set to: $USE_USB_DRIVE"
    else
        info_msg "Using external USB drive setting: $USE_USB_DRIVE"
    fi
}

# Function to get media folder
get_media_folder() {
  load_configuration

  if [ "$USE_USB_DRIVE" = true ]; then
    section_header "Configuring Media Folder"
    info_msg "External USB drive selected. The path will be set to /mnt/usb/media"
    # The docker run command will handle this path directly.
    return
  fi

  # This logic only runs if not using an external USB drive.
  if [ -z "$MEDIA_FOLDER" ] || [ ! -d "$MEDIA_FOLDER" ]; then
    section_header "Configuring Media Folder"
    MEDIA_FOLDER=$(prompt_for_folder "Media" "Enter the folder path for Media folder: ")
    sed -i "/^MEDIA_FOLDER=/d" "$SETTINGS_FILE"
    echo "MEDIA_FOLDER=\"$MEDIA_FOLDER\"" >> "$SETTINGS_FILE"
    success_msg "Media folder set to: $MEDIA_FOLDER"
  else
    info_msg "Using media folder: $MEDIA_FOLDER"
  fi
}

# Function to get GPU config
get_gpu_config() {
  load_configuration

  if [ -z "$USE_GPU" ]; then
    section_header "Configuring GPU Usage"
    read -p "${COLOR_PROMPT}Do you want to use an NVIDIA GPU for detection? (yes/no): ${COLOR_RESET}" use_gpu
    case "$use_gpu" in
      yes)
        USE_GPU=true
        ;;
      no)
        USE_GPU=false
        ;;
      *)
        error_msg "Invalid option. Exiting."
        exit 1
        ;;
    esac
    sed -i "/^USE_GPU=/d" "$SETTINGS_FILE"
    echo "USE_GPU=\"$USE_GPU\"" >> "$SETTINGS_FILE"
    success_msg "NVIDIA GPU usage: $USE_GPU"
  else
    info_msg "Using GPU usage: $USE_GPU"
  fi
}

# Function to generate the YOLOv9 ONNX model
generate_yolov9_model() {
    load_configuration
    section_header "Configuring YOLOv9 Model"

    # Define model cache directory
    MODEL_CACHE="$SCRIPT_DIR/config/model_cache"
    mkdir -p "$MODEL_CACHE"

    if [ -z "$YOLOV9_MODEL_SIZE" ]; then
        info_msg "Available YOLOv9 model sizes: t, s, m, c, e"
        read -p "${COLOR_PROMPT}Enter the YOLOv9 model size you would like to build (default: c): ${COLOR_RESET}" model_size_choice
        YOLOV9_MODEL_SIZE="${model_size_choice:-c}"

        # Validate choice
        if ! [[ "$YOLOV9_MODEL_SIZE" =~ ^(t|s|m|c|e)$ ]]; then
            error_msg "Invalid model size. Please choose from t, s, m, c, or e."
            exit 1
        fi
        sed -i "/^YOLOV9_MODEL_SIZE=/d" "$SETTINGS_FILE"
        echo "YOLOV9_MODEL_SIZE=\"$YOLOV9_MODEL_SIZE\"" >> "$SETTINGS_FILE"
    fi
    success_msg "YOLOv9 model size set to: $YOLOV9_MODEL_SIZE"

    MODEL_FILENAME="yolov9-${YOLOV9_MODEL_SIZE}.onnx"
    MODEL_PATH="$MODEL_CACHE/$MODEL_FILENAME"

    if [ -f "$MODEL_PATH" ]; then
        warn_msg "YOLOv9 model '$MODEL_FILENAME' already exists."
        read -p "${COLOR_PROMPT}Do you want to rebuild it? (yes/no): ${COLOR_RESET}" rebuild_choice
        if [[ "$rebuild_choice" != "yes" ]]; then
            info_msg "Skipping model generation."
            return
        fi
    fi

    info_msg "Starting YOLOv9 ONNX model generation for 'yolov9-${YOLOV9_MODEL_SIZE}'."
    info_msg "This process can take several minutes..."

    # Use a temporary directory for the build to keep the main directory clean
    BUILD_DIR=$(mktemp -d)
    info_msg "Using temporary build directory: $BUILD_DIR"

    # The docker build command provided in the Frigate documentation
    # It builds the model in a container and exports the result to the specified directory
    docker buildx build "$BUILD_DIR" --build-arg MODEL_SIZE="$YOLOV9_MODEL_SIZE" --output "$BUILD_DIR" -f- <<'EOF'
FROM python:3.11 AS build
RUN apt-get update && apt-get install --no-install-recommends -y libgl1 && rm -rf /var/lib/apt/lists/*
COPY --from=ghcr.io/astral-sh/uv:0.8.0 /uv /bin/
WORKDIR /yolov9
ADD https://github.com/WongKinYiu/yolov9.git .
RUN uv pip install --system -r requirements.txt
RUN uv pip install --system onnx onnxruntime onnx-simplifier>=0.4.1
ARG MODEL_SIZE
ADD https://github.com/WongKinYiu/yolov9/releases/download/v0.1/yolov9-${MODEL_SIZE}-converted.pt yolov9-${MODEL_SIZE}.pt
RUN sed -i "s/ckpt = torch.load(attempt_download(w), map_location='cpu')/ckpt = torch.load(attempt_download(w), map_location='cpu', weights_only=False)/g" models/experimental.py
RUN python3 export.py --weights ./yolov9-${MODEL_SIZE}.pt --imgsz 320 --simplify --include onnx
FROM scratch
ARG MODEL_SIZE
COPY --from=build /yolov9/yolov9-${MODEL_SIZE}.onnx /
EOF

    if [ $? -ne 0 ]; then
        error_msg "YOLOv9 model generation failed. Check Docker output for errors."
        rm -rf "$BUILD_DIR" # Clean up temp directory
        exit 1
    fi

    # Move the generated model to the frigate config directory
    mv "$BUILD_DIR/$MODEL_FILENAME" "$MODEL_PATH"
    if [ $? -ne 0 ]; then
        error_msg "Failed to move generated model to $MODEL_PATH"
        rm -rf "$BUILD_DIR" # Clean up temp directory
        exit 1
    fi

    success_msg "YOLOv9 model '$MODEL_FILENAME' generated successfully at $MODEL_PATH"
    rm -rf "$BUILD_DIR" # Clean up temp directory
}


# Function to get Coral config
get_coral() {
  load_configuration

  if [ -z "$USE_CORAL" ]; then
    section_header "Configuring Coral USB Device"
    read -p "${COLOR_PROMPT}Do you want to use a Coral USB device? (yes/no): ${COLOR_RESET}" use_coral
    case "$use_coral" in
      yes)
        USE_CORAL=true
        ;;
      no)
        USE_CORAL=false
        ;;
      *)
        error_msg "Invalid option. Exiting."
        exit 1
        ;;
    esac
    sed -i "/^USE_CORAL=/d" "$SETTINGS_FILE"
    echo "USE_CORAL=\"$USE_CORAL\"" >> "$SETTINGS_FILE"
    success_msg "Coral USB usage: $USE_CORAL"
  else
    info_msg "Using Coral usage: $USE_CORAL"
  fi
}

# Function to get RTSP password
get_rtsp_password() {
  load_configuration

  if [ -z "$RTSP_PASSWORD" ]; then
    section_header "Configuring RTSP Password"
    read -s -p "${COLOR_PROMPT}Enter a password for Frigate RTSP streams (for security): ${COLOR_RESET}" rtsp_password
    echo
    if [ -z "$rtsp_password" ]; then
      warn_msg "No password set. RTSP will be unsecured."
    fi
    rtsp_password=$(printf '%s' "$rtsp_password" | sed 's/[!@#$%^&*()]/\\&/g')
    RTSP_PASSWORD="$rtsp_password"
    sed -i "/^RTSP_PASSWORD=/d" "$SETTINGS_FILE"
    echo "RTSP_PASSWORD=\"$RTSP_PASSWORD\"" >> "$SETTINGS_FILE"
  else
    info_msg "Using existing RTSP password from configuration."
  fi
}

# Function to get Frigate+ API key
get_plus_api_key() {
    load_configuration
    if [ -z "$PLUS_API_KEY" ]; then
        section_header "Configuring Frigate+ API Key"
        read -p "${COLOR_PROMPT}Enter your Frigate+ API key (optional, press Enter to skip): ${COLOR_RESET}" user_api_key
        if [ -n "$user_api_key" ]; then
            PLUS_API_KEY="$user_api_key"
            success_msg "Frigate+ API key has been set."
        else
            PLUS_API_KEY="cde870a5-7d85" # Default example key
            info_msg "No Frigate+ API key entered. Using an example key. This can be changed later."
        fi
        sed -i "/^PLUS_API_KEY=/d" "$SETTINGS_FILE"
        echo "PLUS_API_KEY=\"$PLUS_API_KEY\"" >> "$SETTINGS_FILE"
    else
        info_msg "Using existing Frigate+ API key from configuration."
    fi
}

# Function to pull Frigate image
pull_frigate_image() {
    load_configuration
    section_header "Pulling Frigate Docker Image"

    if [ -z "$FRIGATE_VERSION" ]; then
        DEFAULT_VERSION="stable"
        info_msg "You can specify a version (e.g., 0.13.2), a commit hash, or use 'stable'."
        read -p "${COLOR_PROMPT}Enter the Frigate version tag to install (default: ${DEFAULT_VERSION}): ${COLOR_RESET}" user_version
        # Use the user's input, or the default if they just press Enter
        FRIGATE_VERSION="${user_version:-$DEFAULT_VERSION}"

        if [ -z "$FRIGATE_VERSION" ]; then
            error_msg "Frigate version cannot be empty. Exiting."
            exit 1
        fi

        # Save the selected version for future runs
        sed -i "/^FRIGATE_VERSION=/d" "$SETTINGS_FILE"
        echo "FRIGATE_VERSION=\"$FRIGATE_VERSION\"" >> "$SETTINGS_FILE"
    fi

    success_msg "Preparing to install Frigate version: $FRIGATE_VERSION"

    if [ "$USE_GPU" = true ]; then
        FRIGATE_IMAGE="ghcr.io/blakeblackshear/frigate:${FRIGATE_VERSION}-tensorrt"
    else
        FRIGATE_IMAGE="ghcr.io/blakeblackshear/frigate:${FRIGATE_VERSION}"
    fi

    info_msg "Pulling Frigate image: $FRIGATE_IMAGE"
    docker pull "$FRIGATE_IMAGE" || { error_msg "Error pulling Frigate image. Please check that the version '$FRIGATE_VERSION' exists. Exiting."; exit 1; }
    success_msg "Frigate image pulled successfully."
}

# Function to create Frigate configuration file with detector type
create_frigate_config() {
  load_configuration
  section_header "Creating Frigate Configuration File"

  # Automatically set CONFIG_FOLDER to the script's directory
  CONFIG_FOLDER="$SCRIPT_DIR/config"
  sed -i "/^CONFIG_FOLDER=/d" "$SETTINGS_FILE"
  echo "CONFIG_FOLDER=\"$CONFIG_FOLDER\"" >> "$SETTINGS_FILE"

  # Create the config folder if it doesn't exist
  mkdir -p "$CONFIG_FOLDER" || { error_msg "Error creating config folder. Exiting."; exit 1; }
  info_msg "Config folder: $CONFIG_FOLDER"

  CONFIG_FILE="$CONFIG_FOLDER/config.yml"

  HWACCEL_ARGS="preset-vaapi"
  if [ "$USE_GPU" = true ]; then
    HWACCEL_ARGS="preset-nvidia"
  fi

  info_msg "Generating config.yml with HWACCEL_ARGS: $HWACCEL_ARGS"

  local detector_section=""
  local model_section=""
  if [ "$USE_GPU" = true ]; then
    MODEL_FILENAME="yolov9-${YOLOV9_MODEL_SIZE}.onnx"
    detector_section="
  onnx:
    type: onnx"
    # FIX: Add model_type, input_dtype, and labelmap_path for generic YOLO models
    model_section="
model:
  model_type: yolo-generic
  path: /config/model_cache/$MODEL_FILENAME
  width: 320
  height: 320
  input_tensor: nchw
  input_dtype: float
  labelmap_path: /config/coco-80.txt"

    # Create the labelmap file
    LABELMAP_FILE="$CONFIG_FOLDER/coco-80.txt"
    info_msg "Creating COCO labelmap file at $LABELMAP_FILE"
    cat <<EOF > "$LABELMAP_FILE"
person
bicycle
car
motorcycle
airplane
bus
train
truck
boat
traffic light
fire hydrant
stop sign
parking meter
bench
bird
cat
dog
horse
sheep
cow
elephant
bear
zebra
giraffe
backpack
umbrella
handbag
tie
suitcase
frisbee
skis
snowboard
sports ball
kite
baseball bat
baseball glove
skateboard
surfboard
tennis racket
bottle
wine glass
cup
fork
knife
spoon
bowl
banana
apple
sandwich
orange
broccoli
carrot
hot dog
pizza
donut
cake
chair
couch
potted plant
bed
dining table
toilet
tv
laptop
mouse
remote
keyboard
cell phone
microwave
oven
toaster
sink
refrigerator
book
clock
vase
scissors
teddy bear
hair drier
toothbrush
EOF

  elif [ "$USE_CORAL" = true ]; then
    # Download the labelmap file for Coral if it doesn't exist
    LABELMAP_FILE="$CONFIG_FOLDER/coco_labels.txt"
    if [ ! -f "$LABELMAP_FILE" ]; then
        info_msg "Downloading Coral labelmap file..."
        curl -sL https://raw.githubusercontent.com/google-coral/test_data/master/coco_labels.txt -o "$LABELMAP_FILE" || { error_msg "Failed to download Coral labelmap. Exiting."; exit 1; }
        success_msg "Coral labelmap downloaded to $LABELMAP_FILE"
    fi

    detector_section="
  coral:
    type: edgetpu
    device: usb:0"
    model_section=""
  else
    detector_section="
  cpu:
    type: cpu"
    model_section=""
  fi

  # Start config file
  cat <<EOF > "$CONFIG_FILE"
---
mqtt:
  enabled: false
  host: mqtt.server.com
  user: mqtt_user
  password: password
ffmpeg:
  hwaccel_args: $HWACCEL_ARGS
  retry_interval: 10  # Retry FFmpeg on failure to reduce crashes
snapshots:
  enabled: true
  retain:
    default: 15
    objects:
      person: 15
  quality: 100
$model_section
record:
  enabled: true
  retain:
    days: 14
    mode: all
  events:
    pre_capture: 15
    post_capture: 15
    retain:
      days: 8
      mode: motion
objects:
  track:
    - person
    - car
    - bicycle
    - motorcycle
    - bus
    - cat
    - dog
    - horse
    - sheep
    - cow
    - bear
    - airplane
    - bird
birdseye:
  enabled: false
  mode: continuous
  width: 1920
  height: 1080
audio:
  enabled: false
  listen:
    - scream
    - speech
    - yell
    - skidding
    - tire_squeal
    - emergency_vehicle
    - gunshot
    - glass
    - crack
    - shatter
    - smash
    - breaking
cameras:
  Balcon:
    ui:
      order: 1
    ffmpeg:
      inputs:
        - path: rtsp://97.68.104.34:554/axis-media/media.amp?videocodec=h265
          input_args: preset-rtsp-restream
          roles:
            - detect
            - audio
        - path: rtsp://97.68.104.34:554/axis-media/media.amp?videocodec=h265
          input_args: preset-rtsp-restream
          roles:
            - record
      output_args:
        record: preset-record-generic-audio-aac
    detect:
      width: 640
      height: 360
      fps: 10
    motion:
      mask: 0.562,0.992,0.604,0.996,0.603,0.932,0.56,0.927
semantic_search:
  enabled: false
  reindex: false
  model_size: small
detectors:
$detector_section
EOF

  if [ "$USE_CORAL" = true ]; then
    cat <<EOF >> "$CONFIG_FILE"
  coral2:
    type: edgetpu
    device: usb:1
EOF
    info_msg "Added Coral detectors."
  fi

  success_msg "Frigate config.yml created at $CONFIG_FILE"
}

# Function to start Frigate container
start_frigate_container() {
  load_configuration
  section_header "Starting Frigate Container"

  info_msg "Running Frigate NVR container..."
 
  # Fetch the Docker image name from the saved settings
  if [ "$USE_GPU" = true ]; then
      FRIGATE_IMAGE="ghcr.io/blakeblackshear/frigate:${FRIGATE_VERSION}-tensorrt"
  else
      FRIGATE_IMAGE="ghcr.io/blakeblackshear/frigate:${FRIGATE_VERSION}"
  fi

  # Check if the container already exists
  if docker ps -a --format '{{.Names}}' | grep -q '^frigate$'; then
    if docker ps --format '{{.Names}}' | grep -q '^frigate$'; then
      warn_msg "Frigate container is already running."
      read -p "${COLOR_PROMPT}Do you want to restart it? (y/n): ${COLOR_RESET}" restart
      if [ "$restart" != "y" ]; then
        exit 1
      fi
      docker stop frigate &>/dev/null
    fi
    docker rm frigate &>/dev/null
  fi

  info_msg "Creating and starting Frigate container..."
  # Base docker run command
  DOCKER_RUN_COMMAND="docker run -d \
    --name frigate \
    --restart=unless-stopped \
    --mount type=tmpfs,target=/tmp/cache,tmpfs-size=1000000000 \
    --network=host \
    -v \"$SCRIPT_DIR/config:/config:rw\""

  # Conditionally add media folder volume mount
  if [ "$USE_USB_DRIVE" = true ]; then
      info_msg "Ensuring USB media directory exists at /mnt/usb/media"
      mkdir -p "/mnt/usb/media" || { error_msg "Could not create /mnt/usb/media. Check permissions."; exit 1; }
      DOCKER_RUN_COMMAND="$DOCKER_RUN_COMMAND \
    -v \"/mnt/usb/media:/media:rw\""
  else
      DOCKER_RUN_COMMAND="$DOCKER_RUN_COMMAND \
    -v \"$MEDIA_FOLDER:/media/frigate:rw\""
  fi

  # Add remaining docker run arguments
  DOCKER_RUN_COMMAND="$DOCKER_RUN_COMMAND \
    -v /etc/localtime:/etc/localtime:ro \
    -e PLUS_API_KEY=\"$PLUS_API_KEY\" \
    -e FRIGATE_RTSP_PASSWORD=\"$RTSP_PASSWORD\" \
    --shm-size=1g \
    --privileged"

  if [ "$USE_GPU" = true ]; then
    DOCKER_RUN_COMMAND="$DOCKER_RUN_COMMAND \
      --gpus all \
      -e NVIDIA_VISIBLE_DEVICES=all \
      -e NVIDIA_DRIVER_CAPABILITIES=compute,video,utility"
  fi

  if [ "$USE_USB_DRIVE" = true ]; then
      # This ensures docker has access to USB devices on the host
      DOCKER_RUN_COMMAND="$DOCKER_RUN_COMMAND \
      -v /dev/bus/usb:/dev/bus/usb"
  fi

  if [ "$USE_CORAL" = true ]; then
    DOCKER_RUN_COMMAND="$DOCKER_RUN_COMMAND \
      --device /dev/bus/usb:/dev/bus/usb"
  fi

  DOCKER_RUN_COMMAND="$DOCKER_RUN_COMMAND \
    \"$FRIGATE_IMAGE\""

  eval "$DOCKER_RUN_COMMAND" || { error_msg "Error starting Frigate container. Exiting."; exit 1; }
  success_msg "Frigate container started."

  info_msg "Waiting 30 seconds for container to initialize..."
  sleep 30

  section_header "Frigate Container Logs (Last 50 Lines)"
  docker logs --tail 50 frigate

  success_msg "Frigate NVR setup completed!"
  IP_ADDRESS=$(hostname -I | cut -d ' ' -f1)
  info_msg "Access the Frigate web interface at http://localhost:5000 or http://$IP_ADDRESS:5000"
  read -p "${COLOR_PROMPT}Press Enter to continue...${COLOR_RESET}"
}

# Main function
main() {
  # Ensure the settings file exists before trying to modify it
  touch "$SETTINGS_FILE"

  check_docker
  check_dependencies
  load_configuration

  if [ "$1" == "start" ]; then
    section_header "Starting Frigate Installation"
    get_storage_type
    get_media_folder
    get_gpu_config
    get_coral
    get_rtsp_password
    get_plus_api_key

    if [ "$USE_GPU" = true ]; then
      install_nvidia_dependencies
    fi

    # Ensure Docker is running before proceeding with any docker commands
    ensure_docker_running

    if [ "$USE_GPU" = true ]; then
      generate_yolov9_model
    fi

    pull_frigate_image
    create_frigate_config
    start_frigate_container
    success_msg "Frigate installation and configuration completed!"
    IP_ADDRESS=$(hostname -I | cut -d ' ' -f1)
    info_msg "Access the Frigate web interface at http://localhost:5000 or http://$IP_ADDRESS:5000"
  elif [ "$1" == "stop" ]; then
    ensure_docker_running
    stop_frigate_container
  elif [ "$1" == "delete" ]; then
    ensure_docker_running
    delete_frigate_installation
  elif [ "$1" == "config" ]; then
    create_frigate_config
    success_msg "Frigate config regenerated."
  else
    error_msg "Usage: $0 {start|stop|delete|config}"
    exit 1
  fi
}

# Run the main function with the provided command-line argument
main "$1"


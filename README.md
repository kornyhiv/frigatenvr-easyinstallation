Frigate Easy Install Script

An all-in-one installation and configuration script for Frigate NVR, designed to simplify the setup process on a fresh Debian-based system (like Ubuntu or Debian).

This script automates dependency installation, hardware detection, Frigate configuration, and Docker container management, getting you from a bare OS to a running Frigate instance with just a few commands.


<img width="660" height="867" alt="image" src="https://github.com/user-attachments/assets/b44077ac-3548-4ff1-b297-295fd1c6a3e3" />


Features

•	Automated Dependency Checks: Automatically installs Docker, Docker Buildx, NVIDIA drivers, CUDA, NVCC, and other required tools.

•	Hardware Detection: Automatically detects NVIDIA GPUs for hardware acceleration.

•	Interactive Setup: Prompts the user for key configuration choices like media folder location and hardware usage.

•	YOLOv9 Model Generation: Includes a built-in process to generate a YOLOv9 ONNX model for high-performance object detection on NVIDIA GPUs.

•	Configuration Management: Creates a sensible default config.yml and manages settings through a simple settings file.

•	All-in-One Management: A single script to handle installation, starting, stopping, and complete deletion of the Frigate instance.


Prerequisites

This script is designed for a Debian-based Linux distribution (e.g., Ubuntu 22.04, Debian 12). While it may work on others, it is not guaranteed. The script requires sudo access to install packages and manage the Docker service.


Installation & Usage

1.	Download the script (e.g., frigate_installer.sh) to your server.

2.	Make the script executable:

3.	chmod +x frigate_installer.sh

4.	Run the installer with sudo. It will guide you through the setup process.

5.	sudo ./frigate_installer.sh start


The script will first install all necessary dependencies (this may require a reboot if NVIDIA drivers are installed for the first time). It will then ask you for configuration details and proceed to set up and launch Frigate.

Managing Your Installation

You can use the same script to manage your Frigate instance:

•	Stop the Frigate container:
•	sudo ./frigate_installer.sh stop

•	Delete the entire Frigate installation (this will ask for confirmation before deleting your config and media folders):
•	sudo ./frigate_installer.sh delete

•	Regenerate the config file (useful if you want to start over with the configuration):
•	sudo ./frigate_installer.sh config


Installations only contains one sample camera to get your frigate nvr running. You can edit after the fact and add your cameras. This oftens eliminates the issue that some have with a corrupted config file and are unable to run dfrigate nvr.


Screenshots:


<img width="804" height="770" alt="image" src="https://github.com/user-attachments/assets/08c5c028-b53a-488f-8ec3-da3f5a41e4ab" />

<img width="1641" height="1020" alt="image" src="https://github.com/user-attachments/assets/be64e26b-57e6-406b-bb5e-60d967f65371" />

<img width="1899" height="1025" alt="image" src="https://github.com/user-attachments/assets/767b0c56-1c0b-4718-bc41-0c4c34250890" />

<img width="1348" height="496" alt="image" src="https://github.com/user-attachments/assets/2f146f9c-4fe4-41e4-926b-20a80f1fe9f6" />

<img width="723" height="486" alt="image" src="https://github.com/user-attachments/assets/80da09c1-c8fb-43af-9f8f-27b68d8afa8a" />






Disclaimer & About

This is a community-developed project and is not officially supported by the Frigate team. It was created as a proof-of-concept to explore what was possible. This project is provided "as is" and without any warranty. The author is not responsible for any damage or loss caused by its use. You are using this software at your own risk. This script was developed in collaboration with a large language model (Google's Gemini). The entire process, from initial code generation to debugging and refinement, was guided and validated by Google Gemini, and end users.

This is a community-developed project and is not officially supported by the Frigate team.


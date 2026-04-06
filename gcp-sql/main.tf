terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

##############
# VPC & Subnet
##############

variable "network_name" {
  description = "Name for the custom VPC network."
  type        = string
  default     = "application-deployment"
}

variable "subnet_name" {
  description = "Name for the primary subnet."
  type        = string
  default     = "application-deployment-subnet"
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet."
  type        = string
  default     = "10.0.1.0/24"
}

resource "google_compute_network" "application_deployment" {
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "application_deployment" {
  name          = var.subnet_name
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.application_deployment.id
}

# Mimic GCP default firewall rules for a custom network and add TCP 5000.
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.network_name}-allow-internal"
  network = google_compute_network.application_deployment.name

  direction = "INGRESS"
  priority  = 65534

  source_ranges = ["10.0.0.0/8"]

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
}

resource "google_compute_firewall" "allow_icmp" {
  name    = "${var.network_name}-allow-icmp"
  network = google_compute_network.application_deployment.name

  direction = "INGRESS"
  priority  = 65534

  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "icmp"
  }
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.network_name}-allow-ssh"
  network = google_compute_network.application_deployment.name

  direction = "INGRESS"
  priority  = 65534

  source_ranges = var.ssh_source_ranges

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "allow_http_80" {
  name    = "${var.network_name}-allow-80"
  network = google_compute_network.application_deployment.name

  direction = "INGRESS"
  priority  = 65534

  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

resource "google_compute_firewall" "allow_app_5000" {
  name    = "${var.network_name}-allow-5000"
  network = google_compute_network.application_deployment.name

  direction = "INGRESS"
  priority  = 65534

  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["5000"]
  }
}

resource "google_compute_firewall" "allow_mysql_3306" {
  name    = "${var.network_name}-allow-3306"
  network = google_compute_network.application_deployment.name

  direction = "INGRESS"
  priority  = 65534

  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["3306"]
  }
}

variable "project_id" {
  description = "GCP project ID for the resources."
  type        = string
}

variable "region" {
  description = "Default region for provider operations."
  type        = string
  default     = "europe-west3"
}

variable "zone" {
  description = "Zone for compute resources; must belong to the chosen region."
  type        = string
  default     = "europe-west3-a"
}

variable "instance_name" {
  description = "Name for the VM instance."
  type        = string
  default     = "application-deployment-vm"
}

variable "machine_type" {
  description = "Machine type for the VM."
  type        = string
  default     = "e2-standard-2" # 2 vCPU, 8 GB RAM
}

variable "ssh_source_ranges" {
  description = "CIDR ranges allowed to SSH (22) into the VM."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

########################
# Compute VM (Ubuntu 22)
########################

data "google_compute_image" "ubuntu_2204" {
  family  = "ubuntu-2204-lts"
  project = "ubuntu-os-cloud"
}

resource "google_compute_instance" "application_deployment_vm" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu_2204.self_link
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.application_deployment.id
    access_config {} # ephemeral external IP
  }

  scheduling {
    preemptible       = false
    automatic_restart = true
  }

  tags = ["ssh", "http-5000"]

  metadata = {
    enable-oslogin = "TRUE"
  }
}

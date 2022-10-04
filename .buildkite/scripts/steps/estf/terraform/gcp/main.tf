/*
  GCP Terraform File
  Author: Liza Mae Dayoub
*/

variable "credentials" {
  type = string
  sensitive = true
}

variable "os_image" {
  type = string
}

provider "google" {
  credentials = var.credentials
  project = "elastic-automation"
  region = "us-central1"
}

resource "random_id" "instance_id" {
  byte_length = 8
}

resource "google_compute_instance" "default" {
  name         = "estf-vm-${basename(var.os_image)}-${random_id.instance_id.hex}"
  machine_type = "c2-standard-8"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = var.os_image
      size = "100"
    }
  }

  network_interface {
   network = "default"

    access_config {
      // Include this section to give the VM an external ip address
    }
  }

  // Apply the firewall rule to allow external IPs to access this instance
  tags = ["http-server"]
}

output "IP" {
  value = "${google_compute_instance.default.network_interface.0.access_config.0.nat_ip}"
}

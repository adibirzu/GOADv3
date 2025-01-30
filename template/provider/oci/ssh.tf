locals {
  ssh_public_key = file("${path.module}/ssh_keys/ubuntu-jumpbox.pub")
}

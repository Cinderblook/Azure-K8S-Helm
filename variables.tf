variable "cluster_name" {
  default = "terraformclust"
}

variable "cluster_nodes_count" {
  default = "2"
}

variable "region" {
  default = "East US 2"
}

variable "prefix" {
  default = "test"
}

variable "ssh_public_key"{
  default = "./id_rsa.pub"
}

variable "cloudflare_api_key" {}
variable "cloudflare_email" {}
variable "cloudflare_api_key_secret" {}
variable "cloudflare_prod_account_key" {}
variable "cloudflare_zonid" {}
variable "cloudflare_domainname" {}
variable "cloudflare_token" {}

variable "linux_user" {}

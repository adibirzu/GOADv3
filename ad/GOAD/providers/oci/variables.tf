variable "create_service_gateway" {
  description = "Flag to create the service gateway"
  type        = bool
  default     = false
}
variable "label_prefix" {
  description = "Prefix for resource labels"
  type        = string
  default     = "none"
}

variable "service_gateway_display_name" {
  description = "Display name for the service gateway"
  type        = string
  default     = "Service Gateway"
}


variable "tenancy_ocid" {
  description = "The OCID of your tenancy."
  type        = string
  default = "ocid1.tenancy.oc1..aaaaaaaabh2affulc4doyvq"
}

variable "user_ocid" {
  description = "The OCID of the user calling the API."
  type        = string
  default = "ocid1.user.oc1..aaaaaaaa2hj4okihldoejz2q"
}

variable "fingerprint" {
  description = "The fingerprint of the API key."
  type        = string
  default = "b3:a29:cb"
}

variable "private_key_path" {
  description = "The path to the private key."
  type        = string
  default = "/Users/abirzu/.ssh/newpemkey.pem"
}

variable "region" {
  description = "The region to use."
  type        = string
  default = "eu-frankfurt-1"
}

variable "compartment_ocid" {
  description = "The OCID of the compartment to use."
  type        = string
  default = "ocid1.compartment.oc1..aaaaaaaawwsg5cjj3vmfzda"
}

variable "availability_domain" {
  description = "The availability domain to use."
  type        = string
  default = "fyxu:EU-FRANKFURT-1-AD-1"
}

variable "shape" {
  description = "The shape of the instance to be created."
  type        = string
  default     = "VM.Standard.E5.Flex"
}

variable "ocpus" {
  description = "The number of OCPUs to allocate."
  type        = number
  default     = 1
}

variable "memory_in_gbs" {
  description = "The amount of memory in GBs."
  type        = number
  default     = 12
}

variable "ssh_authorized_keys" {
  description = "The public key for SSH access to the instances."
  type        = string
  default     =  "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDBW/qSv/R+M7Igi4h1unpQmOhQLvOEQiBJ6OQPUA2dY999kRBZuJlIH0CLjHIPf8X0GkvJonhWpFhy6OrSSbcWjjyc6Kbx3y24k3GszixVLMN3tnYNLS8EJ+28NPJDhitXouvAvEAbgo89ZTAwdytBtgiD3BqZi6qSlGlhTCsFlkoaAEzeSdsfE5vxeG+kDBnIrAYp/Oa5r3jjRHOfZaMufun9TEM4E3Ob7SM/HeW5UtESfbTEjySQVOBG7A/RCD7gIhGhhehQkQVJ1MiZ5KGka4uhuCo7qOJECt5Qn5DK5hxGLUL+JKVKgguTDGiClIXe2JdJIobAomguJaM7tlr9 alexandru_@419d0b8d7292"
}

variable "image_ocid" {
  description = "The OCID of the image to use."
  type        = string
  default = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaaxroekfbow3kdrdjlwao6tsxxfcb23xmqrdjtjcay2ow52eijvzqa"
}
variable "windows2016_image_ocid" {
  description = "The OCID of the Windows Server 2016 image."
  type        = string
  default     = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaae2knsz2v5pfsmfahfesqfcxbbtybhtucwxpq7c2lsvi3ouc5aira"
}

variable "windows2019_image_ocid" {
  description = "The OCID of the Windows Server 2019 image."
  type        = string
  default     = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaaq55esthgeydsqq5esexgu3numtsltsfkalqjcee6jit47kwv2vva"
}

variable "freeform_tags" {
  description = "Freeform tags for the resources"
  type        = map(string)
  default     = {}
}
variable "defined_tags" {
  description = "Defined tags for the resources"
  type        = map(string)
  default     = {}
}

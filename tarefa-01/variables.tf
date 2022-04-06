variable "location" {
  description = "Azure Location"
  type        = string
  default     = "westeurope"
}

variable "prefix" {
  description = "Resources prefix"
  type        = string
  default     = "impacta-cloud"
}
   
variable "user" {
  description = "SSH user"
}

variable "password" {
  description = "SSH user password"
}
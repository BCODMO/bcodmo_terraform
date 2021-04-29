variable "region" {
  default = "us-east-1"
}

variable "whoi_ip" {
  default = "128.128.0.0/16"
}

variable "instance_ami" {
  description = "ID of the AMI used"
  type        = string
  default     = "ami-042e8287309f5df03"
}

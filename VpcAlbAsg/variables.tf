variable "vpc_availability_zones" {
  type        = list(string)
  description = "Availability Zones"
  default     = ["us-east-1a", "us-east-1b"]
}

variable "prem_ec2_ws_port" {
  type = number
  description = "Apache WS port"
  default = 80
}
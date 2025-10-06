variable "resource_group_name" {
  description = "اسم مجموعة الموارد الرئيسية"
  type        = string
  default     = "rg-burgerbuilder-prod"
}

variable "location" {
  description = "منطقة Azure"
  type        = string
  default     = "East US"
}

variable "vnet_cidr" {
  description = "CIDR لشبكة VNet الرئيسية"
  type        = string
  default     = "10.0.0.0/16"
}

variable "db_username" {
  description = "Administrator username for PostgreSQL Flexible Server"
  type        = string
  default     = "bgbuilderadmin" #  تغيير هذا الاسم
}

variable "db_password" {
  description = "Administrator password for PostgreSQL Flexible Server"
  type        = string
  sensitive   = true
}
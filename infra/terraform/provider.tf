# ملف: infra/terraform/provider.tf

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      # قم بإزالة سطر النسخة هنا، أو تغييرها إلى ~> 4.0
      # version = "~> 3.0"  <-- قم بحذف هذا السطر أو علقه
    }
  }
}

# تكوين المزود - يتم إجبار Terraform على استخدام هذا الاشتراك والمعرف
provider "azurerm" {
  features {}
  subscription_id = "4421688c-0a8d-4588-8dd0-338c5271d0af"
  tenant_id       = "84f58ce9-43c8-4932-b908-591a8a3007d3"
}
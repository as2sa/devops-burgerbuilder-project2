# 1. Resource Group
resource "azurerm_resource_group" "rg_main" {
  name     = var.resource_group_name
  location = var.location
}

# 2. Virtual Network (VNet)
resource "azurerm_virtual_network" "vnet_main" {
  name                = "vnet-burgerbuilder-prod"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.rg_main.location
  resource_group_name = azurerm_resource_group.rg_main.name
}

# 3. Subnets المطلوبة لنموذج الـ 3-Tier الآمن

# Subnet 1: لـ Application Gateway (WAF) - يجب أن تكون بحجم /24 كحد أدنى
resource "azurerm_subnet" "snet_appgw" {
  name                 = "snet-appgw"
  resource_group_name  = azurerm_resource_group.rg_main.name
  virtual_network_name = azurerm_virtual_network.vnet_main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Subnet 2: للواجهة الأمامية (Frontend Compute/VMs)
resource "azurerm_subnet" "snet_frontend" {
  name                 = "snet-frontend"
  resource_group_name  = azurerm_resource_group.rg_main.name
  virtual_network_name = azurerm_virtual_network.vnet_main.name
  address_prefixes     = ["10.0.10.0/24"]
}

# Subnet 3: للواجهة الخلفية (Backend/API Compute/VMs)
resource "azurerm_subnet" "snet_backend" {
  name                 = "snet-backend"
  resource_group_name  = azurerm_resource_group.rg_main.name
  virtual_network_name = azurerm_virtual_network.vnet_main.name
  address_prefixes     = ["10.0.20.0/24"]
}

# Subnet 4: للعمليات (Operations/Bastion) - لـ Sonarqube/SSH المقيد
resource "azurerm_subnet" "snet_ops" {
  name                 = "snet-ops"
  resource_group_name  = azurerm_resource_group.rg_main.name
  virtual_network_name = azurerm_virtual_network.vnet_main.name
  address_prefixes     = ["10.0.30.0/24"]
}

# Subnet 5: لقاعدة البيانات (Data) - لـ Private Endpoint
resource "azurerm_subnet" "snet_data" {
  name                 = "snet-data"
  resource_group_name  = azurerm_resource_group.rg_main.name
  virtual_network_name = azurerm_virtual_network.vnet_main.name
  address_prefixes     = ["10.0.40.0/24"]
  # هذا الإعداد ضروري للسماح لـ Private Endpoints
  private_endpoint_network_policies = "Disabled" 
}

# NSG 1: NSG لشبكة Application Gateway (snet-appgw)
# تسمح فقط بالوصول من Azure Load Balancer (مطلوب لـ App Gateway)
resource "azurerm_network_security_group" "nsg_appgw" {
  name                = "nsg-appgw"
  location            = azurerm_resource_group.rg_main.location
  resource_group_name = azurerm_resource_group.rg_main.name
}

# NSG 2: NSG للواجهة الأمامية (Frontend)
resource "azurerm_network_security_group" "nsg_frontend" {
  name                = "nsg-frontend"
  location            = azurerm_resource_group.rg_main.location
  resource_group_name = azurerm_resource_group.rg_main.name
}

# NSG 3: NSG للواجهة الخلفية (Backend/API)
resource "azurerm_network_security_group" "nsg_backend" {
  name                = "nsg-backend"
  location            = azurerm_resource_group.rg_main.location
  resource_group_name = azurerm_resource_group.rg_main.name
}

# NSG 4: NSG للعمليات (Ops/Sonarqube/Runner)
resource "azurerm_network_security_group" "nsg_ops" {
  name                = "nsg-ops"
  location            = azurerm_resource_group.rg_main.location
  resource_group_name = azurerm_resource_group.rg_main.name
}

# ----------------------------------------------------------------
# قواعد الأمان (Security Rules)
# ----------------------------------------------------------------

# القاعدة 1: حركة المرور من App Gateway إلى Frontend (الواجهة الأمامية)
# تسمح بمرور HTTP/HTTPS فقط من شبكة الـ App Gateway
resource "azurerm_network_security_rule" "rule_appgw_to_frontend" {
  name                        = "Allow_AppGW_to_Frontend"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"] 
  
  # السماح بالوصول فقط من شبكة App Gateway الفرعية
  source_address_prefix       = azurerm_subnet.snet_appgw.address_prefixes[0] 
  destination_address_prefix  = "*"
  
  # تطبيق القاعدة على NSG الواجهة الأمامية
  network_security_group_name = azurerm_network_security_group.nsg_frontend.name
  resource_group_name         = azurerm_resource_group.rg_main.name
}

# القاعدة 2: حركة المرور من Frontend إلى Backend (API)
# تسمح بالاتصال بمنفذ الـ Backend (8080) فقط من شبكة Frontend
resource "azurerm_network_security_rule" "rule_frontend_to_backend" {
  name                        = "Allow_Frontend_to_Backend_API"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8080" # منفذ تطبيق Java/Spring Boot
  
  # السماح بالوصول فقط من شبكة Frontend الفرعية
  source_address_prefix       = azurerm_subnet.snet_frontend.address_prefixes[0]
  destination_address_prefix  = "*"
  
  # تطبيق القاعدة على NSG الواجهة الخلفية
  network_security_group_name = azurerm_network_security_group.nsg_backend.name
  resource_group_name         = azurerm_resource_group.rg_main.name
}

# القاعدة 3: حركة المرور لـ SSH (للعمليات/Ansible)
# تسمح بـ SSH (منفذ 22) فقط من شبكة العمليات (Ops)
resource "azurerm_network_security_rule" "rule_ssh_ops" {
  name                        = "Allow_SSH_from_Ops"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  
  # السماح بـ SSH فقط من شبكة العمليات (snet-ops)
  source_address_prefix       = azurerm_subnet.snet_ops.address_prefixes[0] 
  destination_address_prefix  = "*"
  
  # تطبيق هذه القاعدة على NSG الواجهة الأمامية
  network_security_group_name = azurerm_network_security_group.nsg_frontend.name
  resource_group_name         = azurerm_resource_group.rg_main.name
}

# نكرر قاعدة SSH على NSG الـ Backend
resource "azurerm_network_security_rule" "rule_ssh_ops_backend" {
  name                        = "Allow_SSH_from_Ops_Backend"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = azurerm_subnet.snet_ops.address_prefixes[0] 
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.nsg_backend.name
  resource_group_name         = azurerm_resource_group.rg_main.name
}

# 4. ربط NSGs بالشبكات الفرعية

# ربط NSG بشبكة الواجهة الأمامية
resource "azurerm_subnet_network_security_group_association" "frontend_nsg_assoc" {
  subnet_id                 = azurerm_subnet.snet_frontend.id
  network_security_group_id = azurerm_network_security_group.nsg_frontend.id
}

# ربط NSG بشبكة الواجهة الخلفية
resource "azurerm_subnet_network_security_group_association" "backend_nsg_assoc" {
  subnet_id                 = azurerm_subnet.snet_backend.id
  network_security_group_id = azurerm_network_security_group.nsg_backend.id
}

# ربط NSG بشبكة العمليات
resource "azurerm_subnet_network_security_group_association" "ops_nsg_assoc" {
  subnet_id                 = azurerm_subnet.snet_ops.id
  network_security_group_id = azurerm_network_security_group.nsg_ops.id
}

# ربط NSG بشبكة App Gateway
resource "azurerm_subnet_network_security_group_association" "appgw_nsg_assoc" {
  subnet_id                 = azurerm_subnet.snet_appgw.id
  network_security_group_id = azurerm_network_security_group.nsg_appgw.id
}

# 5. Azure Container Registry (ACR) - لتخزين صور التطبيقات
resource "azurerm_container_registry" "acr_main" {
  name                = "acrbgbuilderprod${random_integer.random.result}" # يتطلب اسم فريد عالميًا
  resource_group_name = azurerm_resource_group.rg_main.name
  location            = azurerm_resource_group.rg_main.location
  sku                 = "Standard"
  admin_enabled       = true # لتسهيل استخدام Service Principal في CI/CD
}

# --- شرط أساسي لـ ACR: رقم عشوائي لضمان الاسم الفريد عالمياً ---
resource "random_integer" "random" {
  min = 1000
  max = 9999
}

# 6. Azure Key Vault (لتخزين الأسرار)
resource "azurerm_key_vault" "kv_main" {
  name                        = "kv-bgbuilder-prod-${random_integer.random.result}" # اسم فريد عالمياً
  location                    = azurerm_resource_group.rg_main.location
  resource_group_name         = azurerm_resource_group.rg_main.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 7 # إعداد أمان قياسي
  purge_protection_enabled    = true # إعداد أمان لمنع الحذف النهائي

  # تمكين Private Endpoint فقط، لا داعي لتمكين الوصول العام.
  public_network_access_enabled = false
}

# --- شرط أساسي لـ Key Vault: الحصول على Tenant ID الحالي ---
# (يجب إضافة هذا كمصدر بيانات (Data Source) في ملفك)
data "azurerm_client_config" "current" {}

# 7. Azure Database for PostgreSQL Flexible Server
# resource "azurerm_postgresql_flexible_server" "db_main" {
#   name                   = "db-bgbuilder-prod-${random_integer.random.result}"
#   resource_group_name    = azurerm_resource_group.rg_main.name
#   location               = azurerm_resource_group.rg_main.location
#   version                = "14"
#   sku_name               = "B_Standard_B1ms" # (أو أي اسم كان)
#   storage_mb             = 32768
#   administrator_login    = var.db_username
#   administrator_password = var.db_password
#   delegated_subnet_id    = azurerm_subnet.snet_data.id
#   private_dns_zone_id    = azurerm_private_dns_zone.db_private_dns.id
#   public_network_access_enabled = false
#   tags = {
#     environment = "Prod"
#   }
# }

# 8. Private DNS Zone (ضروري لـ Flexible Server ضمن VNet)
# resource "azurerm_private_dns_zone" "db_private_dns" {
#   name                = "privatelink.postgres.database.azure.com"
#   resource_group_name = azurerm_resource_group.rg_main.name
# }

# 9. ربط Private DNS Zone بالشبكة الافتراضية
# resource "azurerm_private_dns_zone_virtual_network_link" "db_dns_link" {
#   name                  = "vnet-link"
#   resource_group_name   = azurerm_resource_group.rg_main.name
#   private_dns_zone_name = azurerm_private_dns_zone.db_private_dns.name
#   virtual_network_id    = azurerm_virtual_network.vnet_main.id
# }

# 10. Azure Kubernetes Service (AKS)
resource "azurerm_kubernetes_cluster" "aks_main" {
  name                = "aks-burgerbuilder-FINAL-${random_integer.random.result}"
  location            = azurerm_resource_group.rg_main.location
  resource_group_name = azurerm_resource_group.rg_main.name
  dns_prefix          = "burgerbuilder"
  
  # === أضيفي هذا السطر ===

  identity {
    type = "SystemAssigned"
  }

  kubernetes_version = "1.30"

  default_node_pool {
    name                 = "systempool"
    vm_size              = "Standard_D2_v3"
    node_count           = 1
    os_disk_size_gb      = 30
    vnet_subnet_id       = azurerm_subnet.snet_ops.id
    # المكان الصحيح لتعطيل الـ Public IP للعقد
    #enable_node_public_ip = false 
  }

  # تكوين الوصول (إلزام AKS باستخدام الشبكة الداخلية)
  private_cluster_enabled = true
  
  # تم حذف: private_fqdn_enabled = true  (لتجنب الخطأ)
  
  # تكوين الشبكة (ربط AKS بالشبكة الافتراضية)
  network_profile {
    network_plugin     = "azure"
    network_policy     = "calico"
    service_cidr       = "10.200.0.0/16"
    dns_service_ip     = "10.200.0.10"
  }

  tags = {
    environment = "Prod"
  }

   lifecycle {
    # أخبر Terraform بتجاهل أي تحديثات على أي خاصية في تجمع العقد الافتراضي
    ignore_changes = [
      default_node_pool
    ]
  }
}

# 11. إضافة تجمع العقد لتشغيل التطبيق (Frontend/Backend)
resource "azurerm_kubernetes_cluster_node_pool" "app_pool" {
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks_main.id
  name                  = "apppool"
  vm_size               = "Standard_D2_v3"
  node_count            = 2
  os_disk_size_gb       = 30
  vnet_subnet_id        = azurerm_subnet.snet_backend.id
  # المكان الصحيح لتعطيل الـ Public IP للعقد
  #enable_node_public_ip = false 
  priority              = "Regular"
  mode                  = "User"
}

# 12. منح AKS الإذن بالوصول إلى ACR (سحب صور الكونتينرات)
#resource "azurerm_role_assignment" "acr_pull" {
# scope                = azurerm_container_registry.acr_main.id
#role_definition_name = "AcrPull"
#principal_id         = azurerm_kubernetes_cluster.aks_main.kubelet_identity[0].object_id
#}

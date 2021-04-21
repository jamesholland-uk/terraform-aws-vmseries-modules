### BOOTSTRAP
module "bootstrap" {
  for_each                  = var.buckets
  source                    = "../../../bootstrap"
  global_tags               = var.global_tags
  prefix                    = var.bootstrap-prefix
  hostname                  = each.value.name
  iam_instance_profile_name = each.value.iam
  panorama-server           = var.init-cfg.panorama-server
  panorama-server2          = var.init-cfg.panorama-server2
  tplname                   = var.init-cfg.tplname
  dgname                    = var.init-cfg.dgname
  dns-primary               = var.init-cfg.dns-primary
  dns-secondary             = var.init-cfg.dns-secondary
  vm-auth-key               = var.init-cfg.vm-auth-key
  op-command-modes          = var.init-cfg.op-command-modes
}



### VPC
module "vpc" {
  source           = "../../../vpc"
  global_tags      = var.global_tags
  prefix_name_tag  = var.prefix_name_tag
  vpc              = var.vpcs
  vpc_route_tables = var.route_tables
  subnets          = var.vpc_subnets
  # nat_gateways     = var.nat_gateways
  # vpc_endpoints    = var.vpc_endpoints
  security_groups = var.security_groups
}



### VMSERIES
locals {
  buckets_map = {
    for k, bkt in module.bootstrap :
    k => {
      "arn"  = bkt.bucket.arn
      "name" = bkt.bucket.bucket
    }
  }
}


module "vmseries" {
  source              = "../.."
  region              = var.region
  prefix_name_tag     = var.prefix_name_tag
  ssh_key_name        = var.ssh_key_name
  fw_license_type     = var.fw_license_type
  fw_version          = var.fw_version
  fw_instance_type    = var.fw_instance_type
  tags                = var.global_tags
  firewalls           = var.firewalls
  interfaces          = var.interfaces
  subnets_map         = module.vpc.subnet_ids
  security_groups_map = module.vpc.security_group_ids
  buckets_map         = local.buckets_map
}
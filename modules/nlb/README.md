# Palo Alto Networks Network Load Balancer Module for AWS

A Terraform module for deploying a Network Load Balancer in AWS cloud. This can be used both as a public facing Load Balancer (to balance incoming traffic to Firewalls) or as an internal Load Balancer (to balance traffic from Firewalls to the actual application.)

## Usage

Example usage as a public Load Balancer:

* The code below is designed to be used with [`vmseries`](../vmseries/README.md), [`vpc`](../vpc/README.md) and [`subnet_set`](../subnet_set/README.md) modules. Check these modules for information on outputs used in this code.
* Firewalls' public facing interfaces are placed in a subnet set called *untrust*.
* Health check port is set to `80` because it uses the HTTP Management Service (restricted on the firewall to Load Balancer's private IP only). Do not use SSH Management Service for health checks - [please follow this document for details](https://knowledgebase.paloaltonetworks.com/KCSArticleDetail?id=kA14u000000oM4KCAU&lang=en_US%E2%80%A9).

```
module "public_nlb" {
  source = "../../modules/nlb"

  lb_name                 = "public-nlb"
  create_dedicated_eips   = true
  subnets                 = { for k, v in module.security_subnet_sets["untrust"].subnets : k => { id = v.id } }
  vpc_id                  = module.security_vpc.id
  balance_rules = {
    "HTTP-traffic" = {
      protocol          = "TCP"
      port              = "80"
      health_check_port = "80"
      threshold         = 2
      interval          = 10
      target_type       = "ip"
      target_port       = 8080
      targets           = { for k, v in var.vmseries : k => module.vmseries[k].interfaces["untrust"].private_ip }
      stickiness        = true
    }
    "HTTPS-traffic" = {
      protocol          = "TCP"
      port              = "443"
      health_check_port = "80"
      threshold         = 2
      interval          = 10
      target_port       = 8443
      target_type       = "ip"
      targets           = { for k, v in var.vmseries : k => module.vmseries[k].interfaces["untrust"].private_ip }
      stickiness        = true
    }
  }

  tags = var.global_tags
}
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.13.7, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 3.74 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 3.74 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_eip.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_lb.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_balance_rules"></a> [balance\_rules](#input\_balance\_rules) | An object that contains the listener, target group, and health check configuration. <br>It consist of maps of applications like follows:<pre>balance_rules = {<br>  "application_name" = {<br>    protocol            = "communication protocol, since this is a NLB module accepted values are TCP or TLS"<br>    port                = "communication port"<br>    target_type         = "type of the target that will be attached to a target group, no defaults here, has to be provided explicitly (regardless the defaults terraform could accept)"<br>    target_port         = "for target types supporting port values, the port number on which the target accepts communication, defaults to the communication port value"<br>    targets             = "a map of targets, where key is the target name (used to create a name for the target attachment), value is the target ID (IP, resource ID, etc - the actual value depends on the target type)"<br><br>    health_check_port   = "port used by the target group healthcheck, if ommited, `traffic-port` will be used"<br>    threshold           = "number of consecutive health checks before considering target healthy or unhealthy, defaults to 3"<br>    interval            = "time between each health check, between 5 and 300 seconds, defaults to 30s"<br><br>    certificate_arn     = "(TLS ONLY) this is the arn of a certificate"<br>    alpn_policy         = "(TLS ONLY) ALPN policy name, for possible values check (terraform documentation)[https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener#alpn_policy], defaults to `None`"<br>  }<br>}</pre>The `application_name` key is valid only for letters, numbers and a dash (`-`) - that's an AWS limitation.<br><br><hr><br>`protocol` and `port` are used for `listener`, `target group` and `target group attachment`. Partially also for health checks (see below).<br><br><hr><br>All listeners are always of forward action.<br><br><hr><br>If you add FWs as targets, make sure you use `target_type = "ip"` and you provide the correct FW IPs in `target` map. IPs should be from the subnet set that the Load Balancer was created in. An example on how to feed this variable with data:<pre>fw_instance_ips = { for k, v in var.vmseries : k => module.vmseries[k].interfaces["untrust"].private_ip }</pre>For format of `var.vmseries` check the (`vmseries` module)[../vmseries/README.md]. The key is the VM name. By using those keys, we can loop through all vmseries modules and take the private IP from the interface that is assigned to the subnet we require. The subnet can be identified by the subnet set name (like above). In other words, the `for` loop returns the following map:<pre>{<br>  vm01 = "1.1.1.1"<br>  vm02 = "2.2.2.2"<br>  ...<br>}</pre><hr><br>Healthchecks are by default of type TCP. Reason for that is the fact, that HTTP requests might flow through the FW to the actual application. So instead of checking the status of the FW we might check the status of the application.<br><br>You have an option to specify a health check port. This way you can set up a Management Profile with an Administrative Management Service limited only to NLBs private IPs and use a port for that service as the health check port. This way you make sure you separate the actual health check from the application rule's port.<br><br><hr><br>EXAMPLE<pre>balance_rules = {<br>  "HTTPS-APP" = {<br>    protocol          = "TCP"<br>    port              = "443"<br>    health_check_port = "80"<br>    threshold         = 2<br>    interval          = 10<br>    target_port       = 8443<br>    target_type       = "ip"<br>    targets           = { for k, v in var.vmseries : k => module.vmseries[k].interfaces["untrust"].private_ip }<br>    stickiness        = true<br>  }<br>}</pre> | `any` | n/a | yes |
| <a name="input_create_dedicated_eips"></a> [create\_dedicated\_eips](#input\_create\_dedicated\_eips) | If set to `true`, a set of EIPs will be created for each zone/subnet. Otherwise AWS will handle IP management. | `bool` | `false` | no |
| <a name="input_enable_cross_zone_load_balancing"></a> [enable\_cross\_zone\_load\_balancing](#input\_enable\_cross\_zone\_load\_balancing) | Enable load balancing between instances in different AZs. Defaults to `true`. <br>Change to `false` only if absolutely necessary. By default, there is only one FW in each AZ. <br>Turning this off means 1:1 correlation between a public IP assigned to an AZ and a FW deployed in that AZ. | `bool` | `true` | no |
| <a name="input_internal_lb"></a> [internal\_lb](#input\_internal\_lb) | Determines if this Load Balancer will be a public (default) or an internal one. | `bool` | `false` | no |
| <a name="input_lb_name"></a> [lb\_name](#input\_lb\_name) | Name of the Load Balancer to be created | `string` | n/a | yes |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | Map of subnets used with a Network Load Balancer. Each map's key is the availability zone name and the value is an object that has an attribute<br>`id` identifying AWS subnet.<br><br>Examples:<br><br>You can define the values directly:<pre>subnets = {<br>  "us-east-1a" = { id = "snet-123007" }<br>  "us-east-1b" = { id = "snet-123008" }<br>}</pre>You can also use output from the `subnet_sets` module:<pre>subnets        = { for k, v in module.subnet_sets["untrust"].subnets : k => { id = v.id } }</pre> | <pre>map(object({<br>    id = string<br>  }))</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Map of AWS tags to apply to all the created resources. | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the security VPC the Load Balancer should be created in. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lb_fqdn"></a> [lb\_fqdn](#output\_lb\_fqdn) | A FQDN for the Load Balancer. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

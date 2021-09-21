data "aws_acm_certificate" "issued" {
  domain      = var.domain
  statuses    = ["ISSUED"]
  most_recent = true
}

data "aws_route53_zone" "selected" {
  name         = var.domain
  private_zone = false
}

resource "aws_route53_record" "ipv4" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = var.hostname
  type    = "A"

  alias {
    name                   = module.alb.lb_dns_name
    zone_id                = module.alb.lb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "ipv6" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = var.hostname
  type    = "AAAA"

  alias {
    name                   = module.alb.lb_dns_name
    zone_id                = module.alb.lb_zone_id
    evaluate_target_health = true
  }
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 6.0"

  name_prefix = "rtmp-"

  load_balancer_type = "network"

  vpc_id                      = data.terraform_remote_state.vpc.outputs.vpc_id
  subnets                     = data.terraform_remote_state.vpc.outputs.public_subnets
  ip_address_type             = "dualstack"
  listener_ssl_policy_default = "ELBSecurityPolicy-FS-1-2-Res-2020-10"

  target_groups = [
    {
      name_prefix      = "rtmp-"
      backend_port     = 1935
      backend_protocol = "TCP"
      target_type      = "ip"

    }
  ]

  https_listeners = [
    {
      port               = 443
      protocol           = "TLS"
      certificate_arn    = data.aws_acm_certificate.issued.arn
      target_group_index = 0
    }
  ]

  tags = {
    App       = "nginx-rtmp"
    Terraform = "true"
  }
}
#====================================================================================================
# Description : Creates the ECS Cluster with an application load balancer and CloudFront
# Author      : John Santias
# Date        : 01-01-2022
# Version     : 1.0.0
#====================================================================================================

#====================================================================================================
#                                             IAM 
#====================================================================================================
data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
}

#====================================================================================================
#                                             VPC 
#====================================================================================================
resource "aws_security_group" "allow_lb_tls" {
  name        = "allow_lb_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    description = "TLS from Load Balancer"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TLS from Load Balancer"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_ecs_tls" {
  name        = "allow_ecs_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    description = "TLS from Load Balancer"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [ aws_security_group.allow_lb_tls.id ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#====================================================================================================
#                                             ECS 
#====================================================================================================
resource "aws_ecs_cluster" "ecs_cluster_sample" {
  name = var.ecs_cluster_name
}

resource "aws_ecs_task_definition" "ecs_task_def_sample" {
  family                = "${var.ecs_task_name}-family"
  requires_compatibilities = [ "FARGATE" ]
  execution_role_arn    = data.aws_iam_role.ecs_task_execution_role.arn 
  network_mode          = "awsvpc"
  cpu                   = var.ecs_task_cpu
  memory                = var.ecs_task_memory
  container_definitions = <<TASK_DEFINITION
  [{
    "name": "${var.ecs_task_name}",
    "image": "#{ECSTaskImage}",
    "essential": true,
    "portMappings": [
      {
        "containerPort": ${var.ecs_task_port},
        "hostPort": ${var.ecs_task_port}
      }
    ]
  }]
  TASK_DEFINITION
}

resource "aws_ecs_service" "ecs_service_sample" {
  name            = var.ecs_service_name
  cluster         = aws_ecs_cluster.ecs_cluster_sample.id
  task_definition = aws_ecs_task_definition.ecs_task_def_sample.arn
  desired_count   = var.ecs_service_count
  launch_type     = "FARGATE"
  network_configuration {
    subnets       =  var.ecs_service_subnets
    assign_public_ip = true
    security_groups = [ aws_security_group.allow_ecs_tls.id ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.website_tg_sample.arn
    container_name   = var.ecs_task_name
    container_port   = 80
  }

  depends_on = [
    aws_lb.load_balancer_sample,
    aws_lb_target_group.website_tg_sample
  ]
}

#====================================================================================================
#                                             Load Balancer 
#====================================================================================================
resource "aws_lb" "load_balancer_sample" {
  name               = var.ecs_task_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [ aws_security_group.allow_lb_tls.id ]
  subnets            = var.ecs_service_subnets
  
}

resource "aws_lb_listener" "load_balancer_sample_listener" {
  load_balancer_arn = aws_lb.load_balancer_sample.arn
  port              = "80"
  protocol          = "HTTP"
    
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.website_tg_sample.arn
  }
}

resource "aws_lb_target_group" "website_tg_sample" {
  name     = "target-group-sample"
  port     = 80
  protocol = "HTTP"
  target_type = "ip"
  vpc_id = var.vpc_id

  health_check {
    path     = "/"
    protocol = "HTTP"
    interval = 60
  }
}

#====================================================================================================
#                                             CloudFront 
#====================================================================================================

resource "aws_cloudfront_distribution" "elb_distribution" {
  origin {
    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "value"
      origin_ssl_protocols = [ "match-viewer" ]
    }
    domain_name = aws_lb.load_balancer_sample.dns_name
    origin_id   = aws_lb.load_balancer_sample.id
  }
  enabled             = true
  is_ipv6_enabled     = true

  aliases = ["mycustomdomain.com", "www.mycustomdomain.com"] 

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_lb.load_balancer_sample.id

    forwarded_values {
      query_string = true
      cookies {
        forward = "whitelist"
        whitelisted_names = [ "SESS*" ]
      }
      headers = [ "Host", "Origin" ]
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 1
    default_ttl            = 86400
    max_ttl                = 31536000
    compress = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
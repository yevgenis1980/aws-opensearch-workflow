
resource "aws_security_group" "opensearch_public" {
  name        = "opensearch-public-sg"
  description = "Allow public OpenSearch access"
  vpc_id      = aws_vpc.main.id

  # Ingress: allow HTTPS from anywhere (or restrict by IP)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # ⚠️ Public access
  }

  # Egress: allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "opensearch-public-sg"
  }
}

resource "aws_opensearch_domain" "public" {
  domain_name    = "lambda-opensearch-public"
  engine_version = "OpenSearch_2.11"

  cluster_config {
    instance_type = "t3.small.search"
    instance_count = 2
    zone_awareness_enabled = true

    zone_awareness_config {
      availability_zone_count = 2
    }
  }

  vpc_options {
    subnet_ids         = aws_subnet.public[*].id   # 🔹 Public subnets
    security_group_ids = [aws_security_group.opensearch_public.id]
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 20
    volume_type = "gp3"
  }

  encrypt_at_rest {
    enabled = true
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https      = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true

    master_user_options {
      master_user_name     = "admin"
      master_user_password = "SuperSecret123!"
    }
  }

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "es:*"
        Resource  = "arn:aws:es:${var.region}:${data.aws_caller_identity.current.account_id}:domain/lambda-opensearch-public/*"
      }
    ]
  })

  tags = {
    Name = "lambda-opensearch-public"
  }
}

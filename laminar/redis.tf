resource "aws_elasticache_subnet_group" "default" {
  name = "laminar-${var.environment[terraform.workspace]}-cache-subnet"

  subnet_ids = [aws_subnet.subnet_public_a.id, aws_subnet.subnet_public_b.id]
}

resource "aws_elasticache_cluster" "default" {
  cluster_id           = "laminar-${var.environment[terraform.workspace]}"
  engine               = "redis"
  node_type            = "cache.t4g.micro"
  port                 = 6379
  parameter_group_name = "default.redis6.x"
  engine_version       = "6.x"
  num_cache_nodes      = 1
  security_group_ids   = [aws_security_group.laminar.id]
  subnet_group_name    = aws_elasticache_subnet_group.default.name

}

locals {
  redis_address = "redis://:@${aws_elasticache_cluster.default.cache_nodes[0].address}:${aws_elasticache_cluster.default.cache_nodes[0].port}/0"
}

output "redis_address" {
  value       = aws_elasticache_cluster.default.cache_nodes[0].address
  description = "The address for redis"
}

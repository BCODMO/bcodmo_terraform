resource "aws_elasticache_subnet_group" "default" {
  name       = "${terraform.workspace}-cache-subnet"
  subnet_ids = [aws_default_subnet.default_1a.id, aws_default_subnet.default_1b.id]
}

resource "aws_elasticache_cluster" "default" {
  cluster_id           = "laminar-${terraform.workspace}"
  engine               = "redis"
  node_type            = "cache.t4g.micro"
  port                 = 6379
  parameter_group_name = "default.redis6.x"
  engine_version       = "6.x"
  num_cache_nodes      = 1
  security_group_ids   = [aws_security_group.laminar_hidden.id]

}

locals {
  redis_address = "redis://:@${aws_elasticache_cluster.default.cache_nodes[0].address}:${aws_elasticache_cluster.default.cache_nodes[0].port}/0"
}
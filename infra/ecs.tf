resource "aws_ecs_cluster" "n8n" {
  name = "n8n-cluster"
}

resource "aws_ecs_task_definition" "n8n" {
  family                   = "n8n-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "n8n"
      image     = "n8nio/n8n:latest"
      essential = true
      portMappings = [
        {
          containerPort = 5678
          hostPort      = 5678
        }
      ]
      environment = [
        {
          name  = "DB_TYPE"
          value = "postgresdb"
        },
        {
          name  = "DB_POSTGRESDB_HOST"
          value = aws_db_instance.n8n.address
        },
        {
          name  = "DB_POSTGRESDB_PORT"
          value = "5432"
        },
        {
          name  = "DB_POSTGRESDB_DATABASE"
          value = var.db_name
        },
        {
          name  = "DB_POSTGRESDB_USER"
          value = var.db_username
        },
        {
          name  = "DB_POSTGRESDB_PASSWORD"
          value = var.db_password
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "n8n" {
  name            = "n8n-service"
  cluster         = aws_ecs_cluster.n8n.id
  task_definition = aws_ecs_task_definition.n8n.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  network_configuration {
    subnets = [
      aws_subnet.public_a.id,
      aws_subnet.public_b.id
    ]
    security_groups = [
      aws_security_group.n8n_default_sg.id
    ]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.n8n.arn
    container_name   = "n8n"
    container_port   = 5678
  }
}
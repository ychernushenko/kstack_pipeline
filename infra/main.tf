##############################################################################
# VPC
##############################################################################

resource "aws_vpc" "cds" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.cds.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = false
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.cds.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "cds" {
  vpc_id = aws_vpc.cds.id
}

resource "aws_eip" "cds" {
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.cds.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cds.id
  }
}

resource "aws_route_table_association" "prefect" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_nat_gateway" "cds" {
  allocation_id = aws_eip.cds.id
  subnet_id     = aws_subnet.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.cds.id

  route {
    cidr_block = aws_vpc.cds.cidr_block
    gateway_id = "local"
  }

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.cds.id
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "cds" {
  name        = "ecs-security-group"
  description = "Allow traffic from ECS workers"
  vpc_id      = aws_vpc.cds.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_endpoint" "secrets_manager" {
  vpc_id             = aws_vpc.cds.id
  service_name       = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [aws_subnet.private.id]
  security_group_ids = [aws_security_group.cds.id]
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id             = aws_vpc.cds.id
  service_name       = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [aws_subnet.private.id]
  security_group_ids = [aws_security_group.cds.id]
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id             = aws_vpc.cds.id
  service_name       = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [aws_subnet.private.id]
  security_group_ids = [aws_security_group.cds.id]
}

##############################################################################
# ECR and ECS
##############################################################################

resource "aws_ecr_repository" "prefect_agent" {
  name = "${var.ecr_repository_name}-agent"
}

resource "aws_ecr_lifecycle_policy" "prefect_agent" {
  repository = aws_ecr_repository.prefect_agent.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Limit number of images to 2"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 2
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_repository" "prefect" {
  name = var.ecr_repository_name
}

resource "aws_ecr_lifecycle_policy" "prefect" {
  repository = aws_ecr_repository.prefect.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Limit number of images to 2"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 2
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecs_cluster" "prefect_cluster" {
  name = "prefect-cluster"
}

resource "aws_ecs_task_definition" "prefect_work_pool_task" {
  family = "prefect-work-pool-agent-task"
  container_definitions = jsonencode([
    {
      name      = "prefect-container",
      image     = "${var.account_number}.dkr.ecr.${var.region}.amazonaws.com/${var.ecr_repository_name}:latest",
      cpu       = 256,
      memory    = 512,
      essential = true,
    }
  ])
  cpu                      = "256"
  memory                   = "512"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  execution_role_arn       = "arn:aws:iam::${var.account_number}:role/ecs_task_execution_role"
  task_role_arn            = "arn:aws:iam::${var.account_number}:role/ecs_task_execution_role"
  # TODO task_role_arn, where task itself should have access to
}

resource "aws_iam_role" "prefect_work_pool_task" {
  name = "prefect-work-pool-task"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "prefect_work_pool_task" {
  name        = "prefect-work-pool-task"
  description = "Policy for ECS tasks to pull images from ECR and manage tasks"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecs:RunTask",
          "ecs:DescribeTasks",
          "ecs:StopTask",
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ecs:TagResource",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "iam:PassRole",
          "emr-serverless:*",
          "s3:*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "prefect_work_pool_task" {
  policy_arn = aws_iam_policy.prefect_work_pool_task.arn
  role       = aws_iam_role.prefect_work_pool_task.name
}


resource "aws_iam_role" "prefect_work_pool_execution" {
  name = "prefect-work-pool-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "prefect_work_pool_execution_secret_policy" {
  name        = "prefect-work-pool-execution-secret-policy"
  description = "Policy to allow ECS tasks to access the secret"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.prefect_api_key.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_prefect_task_secret_policy" {
  policy_arn = aws_iam_policy.prefect_work_pool_execution_secret_policy.arn
  role       = aws_iam_role.prefect_work_pool_execution.name
}

resource "aws_iam_role_policy_attachment" "attach_ecs_task_execution_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.prefect_work_pool_execution.name
}

resource "aws_cloudwatch_log_group" "prefect_work_pool_agent_logs" {
  name              = "/ecs/prefect-work-pool-agent"
  retention_in_days = 7
}

resource "local_file" "work_pool_template" {
  content = jsonencode({
    "job_configuration" : {
      "cluster" : "${aws_ecs_cluster.prefect_cluster.id}",
      "task_definition" : "${aws_ecs_task_definition.prefect_work_pool_task.arn}",
      "subnets" : ["${aws_subnet.private.id}"],
      "security_groups" : ["${aws_security_group.cds.id}"],
      "launch_type" : "FARGATE"
    },
    "variables" : {
      "properties" : {
        "image" : {
          "anyOf" : [
            {
              "type" : "string"
            },
            {
              "type" : "null"
            }
          ],
          "default" : "${var.account_number}.dkr.ecr.${var.region}.amazonaws.com/${var.ecr_repository_name}:latest",
          "description" : "The image to use for the Prefect container in the task. If this value is not null, it will override the value in the task definition. This value defaults to a Prefect base image matching your local versions.",
          "title" : "Image"
        }
      }
    }
  })
  filename = abspath("${path.module}/work_pool_template.json")
}

# Done manually
# resource "null_resource" "create_prefect_work_pool" {
#   provisioner "local-exec" {
#     command = "prefect work-pool create clouddatastack-ecs-worker-pool --type ecs --base-job-template ${local_file.work_pool_template.filename}"
#   }
#   depends_on = [local_file.work_pool_template]
# }

resource "aws_ecs_task_definition" "prefect_work_pool_agent" {
  family = "prefect-agent-pool-agent-task"
  container_definitions = jsonencode([
    {
      name      = "prefect-container",
      image     = "${var.account_number}.dkr.ecr.${var.region}.amazonaws.com/${var.ecr_repository_name}-agent:latest",
      cpu       = 256,
      memory    = 512,
      essential = true,
      command = [
        "sh", "-c", "prefect worker start --pool ${var.prefect_work_pool_name}"
      ]
      environment = [
        {
          name  = "PREFECT_API_KEY",
          value = "${aws_secretsmanager_secret_version.prefect_api_key.secret_string}"
        },
        {
          name  = "PREFECT_API_URL",
          value = "https://api.prefect.cloud/api/accounts/${var.prefect_account_id}/workspaces/${var.prefect_workspace_id}"
        }
      ],
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "${aws_cloudwatch_log_group.prefect_work_pool_agent_logs.name}"
          "awslogs-region"        = "${var.region}"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
  cpu                      = "256"
  memory                   = "512"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.prefect_work_pool_execution.arn
  task_role_arn            = aws_iam_role.prefect_work_pool_task.arn

  # depends_on = [aws_cloudwatch_log_group.prefect_work_pool_agent_logs, null_resource.create_prefect_work_pool]
  depends_on = [aws_cloudwatch_log_group.prefect_work_pool_agent_logs]
}

resource "aws_secretsmanager_secret" "prefect_api_key" {
  name                    = "prefect-api-key"
  recovery_window_in_days = 0 # TODO not for prod
}

resource "aws_secretsmanager_secret_version" "prefect_api_key" {
  secret_id     = aws_secretsmanager_secret.prefect_api_key.id
  secret_string = var.prefect_api_key
}

resource "aws_ecs_service" "prefect_service" {
  name            = "prefect-service"
  cluster         = aws_ecs_cluster.prefect_cluster.id
  task_definition = aws_ecs_task_definition.prefect_work_pool_agent.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = [aws_subnet.private.id]
    security_groups  = [aws_security_group.cds.id]
    assign_public_ip = false
  }
}

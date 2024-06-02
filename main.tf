provider "aws" {
  region = "us-east-1"
}
# Blok dostawcy: Określa, że AWS jest dostawcą chmury.
# Region: Ustawia region AWS na us-east-1, który jest regionem Północna Wirginia.

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "P2TerraformVPC"
  }
}
# VPC: Tworzy wirtualną sieć prywatną (VPC), zapewniającą izolowaną przestrzeń sieciową.
# CIDR Block: Określa blok adresów IP dla VPC w notacji CIDR.
# Tags: Dodaje etykietę do VPC dla łatwiejszego identyfikowania w konsoli AWS.

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
}
# Internet Gateway: Umożliwia komunikację między zasobami w VPC a internetem.


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "P2RT-Terraform-Public"
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
}
# Tabela trasowania: Definiuje zasady trasowania dla ruchu sieciowego wewnątrz VPC.
# Trasa domyślna: Umożliwia wszystkim maszynom w podsieciach dostęp do internetu poprzez bramę internetową.

resource "aws_security_group" "my_security_group" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "P2Terraform-security-group"
  }
  # Grupa zabezpieczeń: Zawiera zestaw reguł, które określają dozwolony ruch przychodzący i wychodzący
  # dla skojarzonych zasobów, jak instancje EC2.

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
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
# Podsieci: Tworzy dwa segmenty sieci w różnych strefach dostępności, co zwiększa dostępność i odporność aplikacji.


# Create public subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "P2Public-1a"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "P2Public-1b"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public.id
}

# Create ECS cluster
resource "aws_ecs_cluster" "cluster" {
  name = "terraformcluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Create task
resource "aws_ecs_task_definition" "terraformtask" {
  family                   = "terraformfamily"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = "arn:aws:iam::781937605669:role/LabRole"
  task_role_arn            = "arn:aws:iam::781937605669:role/LabRole"
  container_definitions    = jsonencode([
    {
      name         = "Frontend"
      image        = "781937605669.dkr.ecr.us-east-1.amazonaws.com/tictactoe-frontend"
      cpu          = 512
      memory       = 1024
      essential    = true
      portMappings = [
        {
          containerPort = 443
          hostPort      = 443
          appProtocol   = "http"
          protocol      = "tcp"
        },
        {
          containerPort = 80
          hostPort      = 80
          appProtocol   = "http"
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/",
          awslogs-region        = "us-east-1",
          awslogs-create-group  = "true",
          awslogs-stream-prefix = "ecs"
        }
      }
    },
    {
      name         = "Backend"
      image        = "781937605669.dkr.ecr.us-east-1.amazonaws.com/tictactoe-backend"
      cpu          = 512
      memory       = 1024
      essential    = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          appProtocol   = "http"
          protocol      = "tcp"
        }
      ]
    }
  ])
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}

# Create service
resource "aws_ecs_service" "terraformservice" {
  name            = "terraformservice"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.terraformtask.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
    security_groups  = [aws_security_group.my_security_group.id]
    assign_public_ip = true
  }
}
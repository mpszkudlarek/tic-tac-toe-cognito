provider "aws" {
  region = "us-east-1"
}
# Blok dostawcy: Określa, że AWS jest dostawcą chmury.
# Region: Ustawia region AWS na us-east-1, który jest regionem North Virginia.

resource "aws_vpc" "terraform_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "My_Terraform_VPC"
  }
}
# VPC: Tworzy wirtualną sieć prywatną (VPC), zapewniającą izolowaną przestrzeń sieciową.
# CIDR Block: Określa blok adresów IP dla VPC w notacji CIDR.
# Tags: Dodaje etykietę do VPC dla łatwiejszego identyfikowania w konsoli AWS.

resource "aws_internet_gateway" "terraform_igw" {
  vpc_id = aws_vpc.terraform_vpc.id
  tags = {
    Name = "My_Terraform_Internet_Gateway"
  }
}
# Internet Gateway: Umożliwia komunikację między zasobami w VPC a internetem.


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.terraform_vpc.id
  tags = {
    Name = "My_Terraform_Public_Route_Table"
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terraform_igw.id
  }
}
# Tabela trasowania: Definiuje zasady trasowania dla ruchu sieciowego wewnątrz VPC.
# Trasa domyślna: Umożliwia wszystkim maszynom w podsieciach dostęp do internetu poprzez bramę internetową.

resource "aws_security_group" "terraform_sg" {
  vpc_id = aws_vpc.terraform_vpc.id
  tags = {
    Name = "My_Terraform_Security_Group"
  }
  # Grupa zabezpieczeń: Zawiera zestaw reguł, które określają dozwolony ruch przychodzący i wychodzący
  # dla skojarzonych zasobów


  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Reguła przychodząca: Pozwala na ruch przychodzący na porcie 443 z dowolnego adresu IP.

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Reguła wychodząca: Pozwala na ruch wychodzący na dowolny port i protokół do dowolnego adresu IP.
}


# Stworzenie publicznych podsieci
resource "aws_subnet" "terraform_public_subnet_1" {
  vpc_id            = aws_vpc.terraform_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "My_Terraform_Public_Subnet_1"
  }
}
# druga po to, jakby pierwsza nie działała

resource "aws_subnet" "terraform_public_subnet_2" {
  vpc_id            = aws_vpc.terraform_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "My_Terraform_Public_Subnet_2"
  }
}


resource "aws_route_table_association" "terraform_route_table_association_1" {
  subnet_id      = aws_subnet.terraform_public_subnet_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "terraform_route_table_association_2" {
  subnet_id      = aws_subnet.terraform_public_subnet_2.id
  route_table_id = aws_route_table.public.id
}


resource "aws_ecs_cluster" "terraform_cluster" {
  name = "My_Terraform_ECS_Cluster"

  setting {
    # Włączenie opcji CloudWatch Container Insights
    name  = "containerInsights"
    value = "enabled"
  }
  tags = {
    Name = "My_Terraform_ECS_Cluster"
  }
}

# Create task
resource "aws_ecs_task_definition" "terraform_task" {
  family = "terraformfamily" # nazwa rodziny zadań
  requires_compatibilities = ["FARGATE"] # platforma uruchomieniowa
  network_mode = "awsvpc" # tryb sieciowy
  cpu = 1024 # ilość zasobów CPU
  memory = 2048 # ilość pamięci
  execution_role_arn = "arn:aws:iam::077137758906:role/LabRole" # Amazon Resource Name (ARN) roli IAM, execution jest uzywana do zarzadzania konterami 
  task_role_arn = "arn:aws:iam::077137758906:role/LabRole" # rola task jest uzywana przez aplikacje w kontenerach do dostępu do usług AWS
  container_definitions = jsonencode([
    {
      # kod z json'a do stworzenia kontenera
      name = "awsttt-frontend"  # nazwa kontenera
      image = "077137758906.dkr.ecr.us-east-1.amazonaws.com/awsttt-frontend" # docker image
      cpu = 512 # ilość zasobów CPU
      memory = 1024 # ilość pamięci
      essential = true # czy kontener jest niezbędny, to znaczy, że bez niego sewis nie wstanie
      portMappings = [
        {
          containerPort = 443 # port kontenera
          hostPort = 443 # port hosta
          appProtocol = "http" # protocol aplikacji
          protocol = "tcp" # typ protokołu
        },
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
      name         = "awsttt-backend"
      image        = "077137758906.dkr.ecr.us-east-1.amazonaws.com/awsttt-backend"
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

resource "aws_ecs_service" "terraform_service" {
  name = "My_Terraform_ECS_Service" # nazwa serwisu 
  cluster = aws_ecs_cluster.terraform_cluster.id # id klastra
  task_definition = aws_ecs_task_definition.terraform_task.arn # amazon resource name(ARN) definicji zadania, ktore maja byc uruchomione na usłudze ECS
  desired_count = 1
  # Liczba egzemplarzy zadania, które powinny być uruchamiane przez usługę w każdym momencie. W tym przypadku 1 oznacza, że chcesz mieć zawsze uruchomione jedno zadanie.
  launch_type = "FARGATE"
  network_configuration {
    subnets          = [aws_subnet.terraform_public_subnet_1.id, aws_subnet.terraform_public_subnet_2.id]
    security_groups  = [aws_security_group.terraform_sg.id]
    assign_public_ip = true
  }
}


resource "aws_vpc_endpoint" "terraform_dynamodb_endpoint" {
  vpc_id = aws_vpc.terraform_vpc.id # vpc w ktorym ma byc endpoint
  service_name = "com.amazonaws.us-east-1.dynamodb" # nazwa usługi, dla której tworzony jest endpoint
  vpc_endpoint_type = "Gateway" # typ endpointu

  route_table_ids = [aws_route_table.public.id] # tabel trasowania, które mają być skojarzone z endpointem, umożliwiając trasowanie ruchu do DynamoDB przez ten endpoint.

  tags = {
    Name = "My_Terraform_DynamoDB_Endpoint"
  }
}
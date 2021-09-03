# ---- mtc networking/main.tf -----

locals {
  security-groups = {
    public = {
      name        = "public-sg"
      description = "public access"
      ingress = {
        open = {
          from        = 0
          to          = 0
          protocol    = -1
          cidr_blocks = ["0.0.0.0/0"]
        }
        tg = {
          from        = 8000
          to          = 8000
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }
        http = {
          from        = 80
          to          = 80
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }
      }
    }
    rds = {
      name        = "rds-sg"
      description = "rds access"
      ingress = {
        mysql = {
          from        = 3306
          to          = 3306
          protocol    = "tcp"
          cidr_blocks = ["10.123.0.0/16"]
        }
      }
    }
  }
}


data "aws_availability_zones" "available" {}

resource "random_integer" "random" {
  min = 1
  max = 99
}

resource "random_shuffle" "public-az" {
  input        = data.aws_availability_zones.available.names
  result_count = var.max_subnets
}

resource "aws_vpc" "mtc-vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "mtc-vpc-${random_integer.random.id}"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_subnet" "mtc-public-subnet" {
  count                   = var.public_sn_count
  vpc_id                  = aws_vpc.mtc-vpc.id
  cidr_block              = var.public_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone       = random_shuffle.public-az.result[count.index]

  tags = {
    Name = "mtc-public-${count.index + 1}"
  }
}

resource "aws_subnet" "mtc-private-subnet" {
  count                   = var.private_sn_count
  vpc_id                  = aws_vpc.mtc-vpc.id
  cidr_block              = var.private_cidrs[count.index]
  map_public_ip_on_launch = false
  availability_zone       = random_shuffle.public-az.result[count.index]

  tags = {
    Name = "mtc-private-${count.index + 1}"
  }
}

resource "aws_db_subnet_group" "mtc-rds-subnetgroup" {
  count      = var.db_subnet_group == "true" ? 1 : 0
  name       = "mtc-rds-subnetgroup"
  subnet_ids = aws_subnet.mtc-private-subnet.*.id
  tags = {
    Name = "mtc-rds-sng"
  }
}

resource "aws_internet_gateway" "mtc-internet-gateway" {
  vpc_id = aws_vpc.mtc-vpc.id

  tags = {
    Name = "mtc-igw"
  }
}

resource "aws_route_table" "mtc-public-rt" {
  vpc_id = aws_vpc.mtc-vpc.id

  tags = {
    Name = "mtc-public"
  }
}


resource "aws_route" "default-route" {
  route_table_id         = aws_route_table.mtc-public-rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.mtc-internet-gateway.id
}


resource "aws_default_route_table" "mtc-private-rt" {
  default_route_table_id = aws_vpc.mtc-vpc.default_route_table_id

  tags = {
    Name = "mtc-private"
  }
}

resource "aws_route_table_association" "mtc-public-assoc" {
  count          = var.public_sn_count
  subnet_id      = aws_subnet.mtc-public-subnet.*.id[count.index]
  route_table_id = aws_route_table.mtc-public-rt.id
}

resource "aws_security_group" "mtc-sg" {
  for_each    = local.security-groups
  name        = each.value.name
  description = each.value.description
  vpc_id      = aws_vpc.mtc-vpc.id



  #public Security Group
  dynamic "ingress" {
    for_each = each.value.ingress
    content {
      from_port   = ingress.value.from
      to_port     = ingress.value.to
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

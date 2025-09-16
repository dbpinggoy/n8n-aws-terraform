resource "aws_vpc" "n8n" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "n8n-vpc"
  }
}

resource "aws_internet_gateway" "n8n" {
  vpc_id = aws_vpc.n8n.id

  tags = {
    Name = "n8n-igw"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.n8n.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.az_a
  map_public_ip_on_launch = true

  tags = {
    Name = "n8n-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.n8n.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = var.az_b
  map_public_ip_on_launch = true

  tags = {
    Name = "n8n-public-b"
  }
}

resource "aws_route_table" "n8n_public_rt" {
  vpc_id = aws_vpc.n8n.id

  tags = {
    Name = "n8n-public-rt"
  }
}

resource "aws_route" "public_internet_route" {
  route_table_id         = aws_route_table.n8n_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.n8n.id
}

resource "aws_route_table_association" "public_a_assoc" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.n8n_public_rt.id
}

resource "aws_route_table_association" "public_b_assoc" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.n8n_public_rt.id
}
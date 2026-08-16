resource "aws_subnet" "public" {
  count = 2

  vpc_id = aws_vpc.fieldops.id
  cidr_block = element(
    ["10.0.1.0/24", "10.0.2.0/24"],
    count.index
  )
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "fieldops-${var.environment}-public-${count.index + 1}"
    Tier = "public"
  }
}

resource "aws_subnet" "application" {
  count = 2

  vpc_id = aws_vpc.fieldops.id
  cidr_block = element(
    ["10.0.11.0/24", "10.0.12.0/24"],
    count.index
  )
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "fieldops-${var.environment}-app-${count.index + 1}"
    Tier = "application"
  }
}

resource "aws_subnet" "database" {
  count = 2

  vpc_id = aws_vpc.fieldops.id
  cidr_block = element(
    ["10.0.21.0/24", "10.0.22.0/24"],
    count.index
  )
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "fieldops-${var.environment}-db-${count.index + 1}"
    Tier = "database"
  }
}
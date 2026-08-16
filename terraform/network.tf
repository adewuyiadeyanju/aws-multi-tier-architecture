resource "aws_internet_gateway" "fieldops" {
  vpc_id = aws_vpc.fieldops.id

  tags = {
    Name = "fieldops-${var.environment}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.fieldops.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.fieldops.id
  }

  tags = {
    Name = "fieldops-${var.environment}-public-rt"
  }
}
resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
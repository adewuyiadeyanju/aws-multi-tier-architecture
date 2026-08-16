resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "fieldops-${var.environment}-nat-eip"
  }
}

resource "aws_nat_gateway" "fieldops" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[1].id

  depends_on = [
    aws_internet_gateway.fieldops
  ]

  tags = {
    Name = "fieldops-${var.environment}-nat"
  }
}

resource "aws_route_table" "application" {
  count = 2

  vpc_id = aws_vpc.fieldops.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.fieldops.id
  }

  tags = {
    Name = "fieldops-${var.environment}-app-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "application" {
  count = 2

  subnet_id      = aws_subnet.application[count.index].id
  route_table_id = aws_route_table.application[count.index].id
}
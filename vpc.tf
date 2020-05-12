resource aws_vpc sari {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "sari-vpc"
  }
}

resource aws_internet_gateway default {
  vpc_id = aws_vpc.sari.id
}

resource aws_subnet public {
  vpc_id            = aws_vpc.sari.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "sari-subnet-public"
  }
}

resource aws_route_table public {
  vpc_id = aws_vpc.sari.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default.id
  }

  tags = {
    Name = "sari-rt-public"
  }
}

resource aws_route_table_association public {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource aws_subnet private1 {
  vpc_id            = aws_vpc.sari.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "sari-subnet-private-1"
  }
}

resource aws_subnet private2 {
  vpc_id            = aws_vpc.sari.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}c"

  tags = {
    Name = "sari-subnet-private-2"
  }
}

resource aws_eip nat {
  vpc = true
}

resource aws_nat_gateway nat {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
}

resource aws_route_table private {
  vpc_id = aws_vpc.sari.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "sari-rt-private"
  }
}

resource aws_route_table_association private1 {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private.id
}

resource aws_route_table_association private2 {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private.id
}

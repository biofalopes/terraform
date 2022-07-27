resource "aws_vpc" "biofa_vpc" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }

}

resource "aws_subnet" "biofa_public_subnet" {
  vpc_id                  = aws_vpc.biofa_vpc.id
  cidr_block              = "10.123.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"

  tags = {
    Name = "dev-public"
  }
}

resource "aws_internet_gateway" "biofa_internet_gw" {
  vpc_id = aws_vpc.biofa_vpc.id

  tags = {
    Name = "dev-igw"
  }
}

resource "aws_route_table" "biofa_public_rt" {
  vpc_id = aws_vpc.biofa_vpc.id

  tags = {
    Name = "dev-public-rt"
  }
}

resource "aws_route" "biofa_default_route" {
  route_table_id         = aws_route_table.biofa_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.biofa_internet_gw.id

}

resource "aws_main_route_table_association" "biofa_public_assoc" {
  vpc_id         = aws_vpc.biofa_vpc.id
  route_table_id = aws_route_table.biofa_public_rt.id
}
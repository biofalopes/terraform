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

resource "aws_security_group" "biofa_sg" {
  name        = "biofa-sg"
  description = "Biofa Security Group"
  vpc_id      = aws_vpc.biofa_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["200.146.10.153/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "biofa-sg"
  }
}

resource "aws_key_pair" "biofa_key" {
  key_name   = "biofa-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCccwUCYOYK/ldJUvh71+u8Gdrzg6zFQYILYdM6ZTcKUS6qRlAqt0Kkrppi+RtVaUkMOke56L8uwWnSrt+ZfO9KXqJiigy+SSAFnPp2CsWIFabPsJ1d07Rmz3kzN15gsbJwuDfgdhEPyf06gZtTLaAyQ2QymRAmMNRrk9/OmYVM73pJo3obrFF46kenY6NtE/0LCorHP3wU1FzTFqa66HkC3fSpMIEasQf67IVd60OoiyLe1y+fnH0cpSGlCwRjvn3u7+6+okaPnKlKFZHOWW4pdUD1sm62c81myQ1F1gmSmP4FME3PbtIqaBJyIg6KHrteCdrWS+IZPEWWr4gKUrnn fabio"
}

resource "aws_instance" "biofa_node" {
  ami                    = data.aws_ami.server_ami.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.biofa_key.id
  vpc_security_group_ids = [aws_security_group.biofa_sg.id]
  subnet_id              = aws_subnet.biofa_public_subnet.id
  user_data              = file("userdata.tpl")

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "biofa-node"
  }
}
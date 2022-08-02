resource "aws_vpc" "mando_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "Mando VPC"
  }
}

resource "aws_subnet" "mando_public_subnet_us_east_1a" {
  vpc_id            = aws_vpc.mando_vpc.id
  cidr_block        = "10.10.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Mando Public Subnet US-East 1a"
  }
}

resource "aws_subnet" "mando_public_subnet_us_east_1b" {
  vpc_id            = aws_vpc.mando_vpc.id
  cidr_block        = "10.10.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Mando Public Subnet US-East 1b"
  }
}

resource "aws_internet_gateway" "mando_vpc_igw" {
  vpc_id = aws_vpc.mando_vpc.id

  tags = {
    Name = "Mando VPC - Internet Gateway"
  }
}

resource "aws_route_table" "mando_vpc_public" {
  vpc_id = aws_vpc.mando_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mando_vpc_igw.id
  }

  tags = {
    Name = "Public Subnets Route Table for Mando VPC"
  }
}

resource "aws_route_table_association" "mando_vpc_us_east_1a_public" {
  subnet_id      = aws_subnet.mando_public_subnet_us_east_1a.id
  route_table_id = aws_route_table.mando_vpc_public.id
}

resource "aws_route_table_association" "mando_vpc_us_east_1b_public" {
  subnet_id      = aws_subnet.mando_public_subnet_us_east_1b.id
  route_table_id = aws_route_table.mando_vpc_public.id
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound connections"
  vpc_id      = aws_vpc.mando_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow HTTP Security Group"
  }
}

resource "aws_key_pair" "mando_key" {
  key_name   = "mando-key"
  public_key = "ssh-rsa AAAABACH3L0Lc2EAAAADAQAPNCDAgQDELie/jIMM8uno12enId2YTmTjK1OGZJtTJFoSPdXIwn79qpZYQ3WXL8PlI/8dqFyGXvQj5bGJbgEydjSYVHFXFhPr4sdKcjguWbu895EjK2DgalcYuC1+6jBbFxiodoObsc+84m81+BACH3L0LQU3cm/rNKufrh6d21jIe4sQVul+WzJ9E8aPk34rPmRPgjYvh1T/P2hdgiUyJmKqOtDYwpokDRad+3W+iwGfoBACH3L0LoCWJ2rYzz6j80FKoiHm9cnSXvErezT7aAdenVzY3nEE4ylnHWVUdmzXN7IbCSLsDV3sdn0+c5E6oDX2/k1VwtSQ8TrUblM7AdpuB4ADniUSYvLqjd/NBIiHODzV6qZxXqoltVTsrTpbCWf1A063PBACH3L0L/F3mxBihWRAKfD1iqqfMXmYvAPosOkJ3u1yuwy/eCi6Q3SmA5n0vBSVKmYdUB9yQdAimWcUqabRzXLz+g8BrUxCBHwOf4+IZAp2AseJeoDQs0aqMwybr/k= mando" # replace with your key
}

resource "aws_launch_configuration" "web" {
  name_prefix = "web-"

  image_id      = data.aws_ami.server_ami.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.mando_key.id

  security_groups             = [aws_security_group.allow_http.id]
  associate_public_ip_address = true

  user_data = file("userdata.tpl")

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "elb_http" {
  name        = "elb_http"
  description = "Allow HTTP traffic to instances through Elastic Load Balancer"
  vpc_id      = aws_vpc.mando_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow HTTP through ELB Security Group"
  }
}

resource "aws_elb" "web_elb" {
  name = "web-elb"
  security_groups = [
    aws_security_group.elb_http.id
  ]
  subnets = [
    aws_subnet.mando_public_subnet_us_east_1a.id,
    aws_subnet.mando_public_subnet_us_east_1b.id
  ]

  cross_zone_load_balancing = true

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    target              = "HTTP:80/"
  }

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = "80"
    instance_protocol = "http"
  }

}

resource "aws_autoscaling_group" "web" {
  name = "${aws_launch_configuration.web.name}-asg"

  min_size         = 1
  desired_capacity = 2
  max_size         = 4

  health_check_type = "ELB"
  load_balancers = [
    aws_elb.web_elb.id
  ]

  launch_configuration = aws_launch_configuration.web.name

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  metrics_granularity = "1Minute"

  vpc_zone_identifier = [
    aws_subnet.mando_public_subnet_us_east_1a.id,
    aws_subnet.mando_public_subnet_us_east_1b.id
  ]

  # Required to redeploy without an outage.
  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "web"
    propagate_at_launch = true
  }

}

resource "aws_autoscaling_policy" "web_policy_up" {
  name                   = "web_policy_up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web.name
}

resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_up" {
  alarm_name          = "web_cpu_alarm_up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "60"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions     = [aws_autoscaling_policy.web_policy_up.arn]
}

resource "aws_autoscaling_policy" "web_policy_down" {
  name                   = "web_policy_down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web.name
}

resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_down" {
  alarm_name          = "web_cpu_alarm_down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "10"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions     = [aws_autoscaling_policy.web_policy_down.arn]
}
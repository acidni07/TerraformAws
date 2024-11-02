
/**
create ALB and ASG with EC2 hosting apache WS
1. ALB ( SG, LB, target gp, listener)
2. ASG (SG, launch template, ASG)

1 ALB (association: LB -> Listener -> Target gp)
    a. SG (internet => lb)
        vpc id
        name
        ingress
            from_port
            to_port
            protocol
            cidr_blocks
        egress
            from_port
            to_port
            protocol
            cidr_blocks
    b. ALB
        vpc_id
        type
        internal/external
        subnets
        security_groups
        depends_on
    c. Target Group
        vpc_id
        name
        port
        protocol
    d. listener
        lb arn
        port
        protocol
        default_action
            type
            target_group_arn

2. ASG
    a. SG (ALB -> EC2)
        vpc_id
        name
        ingress
            from_port - alb port
            to_port - ec2 port
            port
            protocol
            cidr_blocks
        egress
            from_port
            to_port
            port
            protocol
            cidr_blocks
    b. Launch Template
        name
        image_id
        instance_type
        network_interfaces
            associate_public_ip_address ( we use pvt subnet, hence false)
            security_groups
        user_data
    c. ASG
        name
        vpc_zone_identifier
        target_group_arns
        launch_template
            id
            version
        min_size
        max_size
        desired_capacity
        health_check_type - EC2

*/


#1.a. Security Group for ALB (Internet -> ALB)
resource "aws_security_group" "prem_alb_sg" {
  name        = "prem-alb-sg"
  description = "Security Group for Application Load Balancer"

  vpc_id = aws_vpc.prem_vpc.id

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
    Name = "prem-alb-sg"
  }
}


#1.b. Application Load Balancer
resource "aws_lb" "prem_app_lb" {
  name               = "prem-app-lb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.prem_alb_sg.id]
  subnets            = aws_subnet.prem_pub_snet[*].id
  depends_on         = [aws_internet_gateway.prem_igw]
}

#1.c. Target Group for ALB
resource "aws_lb_target_group" "prem_alb_ec2_tg" {
  name     = "prem-web-server-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.prem_vpc.id
  tags = {
    Name = "prem-prem_alb_ec2_tg"
  }
}
#1.d. Listener for ALB
resource "aws_lb_listener" "prem_alb_listener" {
  load_balancer_arn = aws_lb.prem_app_lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prem_alb_ec2_tg.arn
  }
  tags = {
    Name = "prem-alb-listener"
  }
}

#2.a. Security Group for EC2 Instances (ALB -> EC2)
resource "aws_security_group" "prem_ec2_sg" {
  name        = "prem-ec2-sg"
  description = "Security Group for Web Server Instances"

  vpc_id = aws_vpc.prem_vpc.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.prem_alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "prem-ec2-sg"
  }
}

#2.b. Launch Template for EC2 Instances
resource "aws_launch_template" "prem_ec2_launch_template" {
  name = "prem-web-server"

  image_id      = "ami-0e86e20dae9224db8" #ubuntu
  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.prem_ec2_sg.id]
  }

  user_data = filebase64("userdata.sh")

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "prem-ec2-web-server"
    }
  }
}

#2.c. Auto Scaling Group
resource "aws_autoscaling_group" "prem_ec2_asg" {
  name                = "prem-web-server-asg"
  desired_capacity    = 2
  min_size            = 2
  max_size            = 3
  target_group_arns   = [aws_lb_target_group.prem_alb_ec2_tg.arn]
  vpc_zone_identifier = aws_subnet.prem_pvt_snet[*].id

  launch_template {
    id      = aws_launch_template.prem_ec2_launch_template.id
    version = "$Latest"
  }

  health_check_type = "EC2"
}

output "alb_dns_name" {
  value = aws_lb.prem_app_lb.dns_name
  description = "ALB URL: "
}
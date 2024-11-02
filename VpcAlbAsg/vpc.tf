/**
Create VPC, 4 subnets (2 public & 2 private), IGW and NGW
1. vpc
    CIDR block
    DNS support
    DNS hostname support
2. subnet
    name
    vpc id
    AZ
3. IGW
    vpc id
4. route table for public subnet
    vpc id
    route
        CIRD block (internet)
        gateway id (IGW)
5. route table association for public subnet
    route table id
    subnet id
6. elastic ip
    doomain
    depeds on IGW
7. NGW
    association id (eip)
    vpc id
    depends on IGW
8. route table for private subney
    vpc id
    route
        CIDR block (internet)
        gateway id (NGW)
    depeds on IGW
9. route table asociation for private subnet
    route table id
    subnet id
*/
###############################################################

#1. vpc
resource "aws_vpc" "prem_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "prem-vpc"
  }
}


#2.a. public subnet
resource "aws_subnet" "prem_pub_snet" {
  vpc_id            = aws_vpc.prem_vpc.id
  count             = length(var.vpc_availability_zones)
  cidr_block        = cidrsubnet(aws_vpc.prem_vpc.cidr_block, 8, count.index + 1)
  availability_zone = element(var.vpc_availability_zones, count.index)
  tags = {
    Name = "prem TF Public subnet ${count.index + 1}"
  }
}

#2.b private subnet
resource "aws_subnet" "prem_pvt_snet" {
  vpc_id            = aws_vpc.prem_vpc.id
  count             = length(var.vpc_availability_zones)
  cidr_block        = cidrsubnet(aws_vpc.prem_vpc.cidr_block, 8, count.index + 3)
  availability_zone = element(var.vpc_availability_zones, count.index)
  tags = {
    Name = "prem TF Private subnet ${count.index + 1}"
  }
}

#3. IGW
resource "aws_internet_gateway" "prem_igw" {
  vpc_id = aws_vpc.prem_vpc.id
  tags = {
    Name = "prem TF IGW"
  }
}

#4. Route table (public subnet)
resource "aws_route_table" "prem_pub_snet_rt" {
  vpc_id = aws_vpc.prem_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prem_igw.id
  }
  tags = {
    Name = "prem TF Public subnet Route Table"
  }
}

#5. Route table association (public subnet)
resource "aws_route_table_association" "prem_pub_snet_asso" {
  route_table_id = aws_route_table.prem_pub_snet_rt.id
  count          = length(var.vpc_availability_zones)
  subnet_id      = element(aws_subnet.prem_pub_snet[*].id, count.index)
}

#6. Elastic IP
resource "aws_eip" "prem_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.prem_igw]
}


#7. NAT Gateway
resource "aws_nat_gateway" "prem-nat-gateway" {
  allocation_id = aws_eip.prem_eip.id
  subnet_id     = element(aws_subnet.prem_pub_snet[*].id, 0)
  depends_on    = [aws_internet_gateway.prem_igw]
  tags = {
    Name = "prem TF NGW"
  }
}

#8. Route table (Private subnet)
resource "aws_route_table" "prem_pvt_snet_rt" {
  depends_on = [aws_nat_gateway.prem-nat-gateway]
  vpc_id     = aws_vpc.prem_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.prem-nat-gateway.id
  }
  tags = {
    Name = "prem TF Private subnet Route Table"
  }
}

#9. Route table association (private subnet)
resource "aws_route_table_association" "prem_pvt_snet_association" {
  route_table_id = aws_route_table.prem_pvt_snet_rt.id
  count          = length(var.vpc_availability_zones)
  subnet_id      = element(aws_subnet.prem_pvt_snet[*].id, count.index)
}
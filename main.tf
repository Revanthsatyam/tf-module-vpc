resource "aws_vpc" "main" {
  cidr_block = var.cidr

  tags = {
    Name = "dev"
  }
}

module "subnets" {
  source   = "./subnets"
  for_each = var.subnets
  vpc_id   = aws_vpc.main.id
  subnets  = each.value
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "dev-igw"
  }
}

resource "aws_route" "igw" {
  for_each               = lookup(lookup(module.subnets, "public", null), "route_table_ids", null)
  route_table_id         = each.value["id"]
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_eip" "ngw" {
  count  = length(local.public_subnet_ids)
  domain = "vpc"
}

resource "aws_nat_gateway" "ngw" {
  count         = length(local.public_subnet_ids)
  allocation_id = element(aws_eip.ngw.*.id, count.index)
  subnet_id     = element(local.public_subnet_ids, count.index)
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_route" "ngw" {
  count                  = length(local.private_route_table_ids)
  route_table_id         = element(local.private_route_table_ids, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.ngw.*.id, count.index)
}
terraform {
    backend "s3" {
        region = "us-east-1"
        bucket = "my-terrform-state-file-bucket4532"
        dynamodb_table = "statelock"
        key = "global/mystatefile2/terraform.tfstate"
        encrypt = true
    }

    required_providers {
      aws = {
        source  = "hashicorp/aws"
        version = "~> 5.0"
      }
    }
  }

  provider "aws" {
    alias  = "useast1"
    region = "us-east-1"
  }

  provider "aws" {
    alias  = "uswest2"
    region = "us-west-2"
  }

  resource "aws_vpc" "My_Terraform_VPC_useast1" {
    provider = aws.useast1

    cidr_block       = "10.0.0.0/16"
    instance_tenancy = "default"

    tags = {
      Name = "My_Terraform_VPC_useast1"
    }
  }

  resource "aws_subnet" "Public_subnet_useast1" {
    provider = aws.useast1

    vpc_id            = aws_vpc.My_Terraform_VPC_useast1.id
    cidr_block        = "10.0.1.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true

    tags = {
      Name = "Public_subnet_useast1"
    }
  }

  resource "aws_subnet" "Private_subnet_useast1" {
    provider = aws.useast1

    vpc_id            = aws_vpc.My_Terraform_VPC_useast1.id
    cidr_block        = "10.0.5.0/24"
    availability_zone = "us-east-1a"

    tags = {
      Name = "Private_subnet_useast1"
    }
  }

  resource "aws_internet_gateway" "Internet_Gateway" {
    provider = aws.useast1

    vpc_id = aws_vpc.My_Terraform_VPC_useast1.id

    tags = {
      Name = "Internet_Gateway"
    }
  }

  resource "aws_route_table" "Internet_Gateway_RT" {
    provider = aws.useast1

    vpc_id = aws_vpc.My_Terraform_VPC_useast1.id

    tags = {
      Name = "Internet_Gateway_RT"
    }
  }

  resource "aws_route" "Routes_attachment" {
    provider = aws.useast1

    route_table_id         = aws_route_table.Internet_Gateway_RT.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id             = aws_internet_gateway.Internet_Gateway.id
  }

  resource "aws_route_table_association" "public-subnet-igw-rt" {
    provider = aws.useast1

    subnet_id      = aws_subnet.Public_subnet_useast1.id
    route_table_id = aws_route_table.Internet_Gateway_RT.id
  }

  resource "aws_eip" "elasticIP" {
    provider = aws.useast1

    domain   = "vpc"
  }

  resource "aws_nat_gateway" "NatGateway" {
    provider = aws.useast1

    allocation_id = aws_eip.elasticIP.id
    subnet_id     = aws_subnet.Public_subnet_useast1.id

    tags = {
      Name = "NatGateway"
    }

    depends_on = [aws_internet_gateway.Internet_Gateway]
  }

  resource "aws_route_table" "NatGatewayRT" {
    provider = aws.useast1

    vpc_id = aws_vpc.My_Terraform_VPC_useast1.id

    tags = {
      Name = "NatGatewayRT"
    }
  }

  resource "aws_route" "Nat_Route_attachement" {
    provider = aws.useast1

    route_table_id         = aws_route_table.NatGatewayRT.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id             = aws_nat_gateway.NatGateway.id
  }

  resource "aws_route_table_association" "private_subnet_association-rt" {
    provider = aws.useast1

    subnet_id      = aws_subnet.Private_subnet_useast1.id
    route_table_id = aws_route_table.NatGatewayRT.id
  }

  resource "aws_key_pair" "TerraformKey" {
    provider = aws.useast1

    key_name   = "TerraformKey"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCSI5dkNOZ13Xt8iD99K6twf7TSpvDyeAvXHBkFaQdG0nQ+vXTv6dEk6Wa1IcGjxgH5lFo3yDrEE5+dGdVNKyfG/HWrmU36Ck8UO3iJahM5Nha9ACOURaYPMTulaYm4D4Iny/2btwp0N+XouL88PtgiAloiu/dKZJxb4AQ+Uco+p2aZhx5yxcrsHh9N9XGKYwVsQc23VTg79AdIlAebqAa1L5lKqUXbDQQEwLFvYfVTsb0lo/JfhGoSuO3Exj9dKPOAs4j2vRgIO4oBE/YZmIJQvSipl6hce9Tu1md5mkwwypLfr413lnDQDuXBURedxNYxeU3yHsZRxk0JMrztaEtN rsa-key-20240427"
  }

  resource "aws_instance" "Terraform_public_instance" {
    provider = aws.useast1

    count = 2
    ami  = "ami-04b70fa74e45c3917"
    instance_type = "t2.micro"
    key_name = aws_key_pair.TerraformKey.key_name
    subnet_id = count.index < 1 ? aws_subnet.Public_subnet_useast1.id : aws_subnet.Private_subnet_useast1.id

    tags = {
      Name = count.index < 1 ? "Public_instance-${count.index}" : "Private_instance-${count.index - 1}"
    }

       connection {
      type = "ssh"
      host = self.public_ip
      user = "ubuntu"
      private_key = file("/home/ec2-user/.ssh/id_rsa")
      timeout = "4m"
   }

   provisioner "file" {
      source = "/home/ec2-user/terraform-provisioners/text.txt" #change this according to actual path of your file location
      destination = "/home/ubuntu/text.txt"
   }

   lifecycle {
      create_before_destroy = true
   }

   depends_on = [aws_key_pair.TerraformKey]

  }

  # Resources for us-west-2
  resource "aws_vpc" "My_Terraform_VPC_uswest2" {
    provider = aws.uswest2

    cidr_block       = "10.1.0.0/16"
    instance_tenancy = "default"

    tags = {
      Name = "My_Terraform_VPC_uswest2"
    }
  }

  resource "aws_subnet" "Public_subnet_uswest2" {
    provider = aws.uswest2

    vpc_id            = aws_vpc.My_Terraform_VPC_uswest2.id
    cidr_block        = "10.1.1.0/24"
    availability_zone = "us-west-2a"
    map_public_ip_on_launch = true

    tags = {
      Name = "Public_subnet_uswest2"
    }
  }

  resource "aws_subnet" "Private_subnet_uswest2" {
    provider = aws.uswest2

    vpc_id            = aws_vpc.My_Terraform_VPC_uswest2.id
    cidr_block        = "10.1.5.0/24"
    availability_zone = "us-west-2a"

    tags = {
      Name = "Private_subnet_uswest2"
    }
  }

  resource "aws_internet_gateway" "Internet_Gateway1" {
    provider = aws.uswest2

    vpc_id = aws_vpc.My_Terraform_VPC_uswest2.id

    tags = {
      Name = "Internet_Gateway1"
    }
  }

  resource "aws_route_table" "Internet_Gateway_RT1" {
    provider = aws.uswest2

    vpc_id = aws_vpc.My_Terraform_VPC_uswest2.id

    tags = {
      Name = "Internet_Gateway_RT1"
    }
  }

  resource "aws_route" "Routes_attachment1" {
    provider = aws.uswest2

    route_table_id         = aws_route_table.Internet_Gateway_RT1.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id             = aws_internet_gateway.Internet_Gateway1.id
  }

  resource "aws_route_table_association" "public-subnet-igw-rt1" {
    provider = aws.uswest2

    subnet_id      = aws_subnet.Public_subnet_uswest2.id
    route_table_id = aws_route_table.Internet_Gateway_RT1.id
  }

  resource "aws_eip" "elasticIP1" {
    provider = aws.uswest2

    domain   = "vpc"
  }

  resource "aws_nat_gateway" "NatGateway1" {
    provider = aws.uswest2

    allocation_id = aws_eip.elasticIP1.id
    subnet_id     = aws_subnet.Public_subnet_uswest2.id

    tags = {
      Name = "NatGateway1"
    }

    depends_on = [aws_internet_gateway.Internet_Gateway1]
  }

  resource "aws_route_table" "NatGatewayRT1" {
    provider = aws.uswest2

    vpc_id = aws_vpc.My_Terraform_VPC_uswest2.id

    tags = {
      Name = "NatGatewayRT1"
    }
  }

  resource "aws_route" "Nat_Route_attachement1" {
    provider = aws.uswest2

    route_table_id         = aws_route_table.NatGatewayRT1.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id             = aws_nat_gateway.NatGateway1.id
  }

  resource "aws_route_table_association" "private_subnet_association-rt1" {
    provider = aws.uswest2

    subnet_id      = aws_subnet.Private_subnet_uswest2.id
    route_table_id = aws_route_table.NatGatewayRT1.id
  }

  resource "aws_key_pair" "TerraformKey1" {
    provider = aws.uswest2

    key_name   = "uswest2key"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCKdmuaBVlsminqCnPaIzve7mcy313JhQRiud794tnBFnKv4qm64Eu30oHvQkdS+os0QPPcJJTVDa3i0YY3qMgwYtokJJDb26PWB+LQJeRa5+vQuqnij6QYqmQoG82c/rwbutHo0uV3rdEbUFhUk8vig4VzwCVsbUfH4gPrJ5YcV35Nvp+QFXQcNyDT1oQtvV3svIgzvyWanTktoCWOsEulDe0DIau2ohS81Q5HvYiHm5lQaZIGPb+b1Uu2kGGCKogHVj8I2IV/5YcjoPwZeMOuFmUNK8EAFc2rZBZx/7vsJzHoNlqUdhYthNeUOs6mWZLL5Y7aDJ09zZPNGz80C+AB rsa-key-20240427"
  }

  resource "aws_instance" "Terraform_instances_uswest2" {
   provider = aws.uswest2

    count = 2
    ami  = "ami-0663b059c6536cac8"
    instance_type = "t2.micro"
    key_name = aws_key_pair.TerraformKey1.key_name
    subnet_id = count.index < 1 ? aws_subnet.Public_subnet_uswest2.id : aws_subnet.Private_subnet_uswest2.id

    tags = {
      Name = count.index < 1 ? "Public_instance-${count.index}" : "Private_instance-${count.index - 1}"
    }

    connection {
      type = "ssh"
      host = self.public_ip
      user = "ubuntu"
      private_key = file("/home/ec2-user/.ssh/id_rsa") #add private key here check with your key pair name and location
      timeout = "4m"
   }

   provisioner "file" {
      source = "/home/ec2-user/terraform-provisioners/text.txt" #need to change to our file location
      destination = "/home/ubuntu/text.txt"
   }

   lifecycle {
      create_before_destroy = true
   }

   depends_on = [aws_key_pair.TerraformKey1]
}


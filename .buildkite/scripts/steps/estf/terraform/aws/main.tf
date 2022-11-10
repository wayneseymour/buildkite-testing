/*
  AWS Terraform File
  Author: Liza Mae Dayoub
*/

provider "aws" {
  access_key = ""
  secret_key = ""
  region = "us-west-2"
}

resource "random_id" "instance_id" {
  byte_length = 8
}

resource "aws_ebs_volume" "default" {
  availability_zone = "us-west-2a"
  size = 100
  tags = {
    owner = "estf"
    divison = "engineering"
    org = "appex"
    team = "kibana"
    project = "support_matrix"
    engineer = "liza_dayoub"
  }
}

resource "aws_instance" "default" {
  count = 1
  ami  = "ami-0d593311db5abb72b"
  instance_type = "t2.large"
  subnet_id = "subnet-01e364448c2f26e82"
  associate_public_ip_address = true
  key_name = "estf-aws-key"
  vpc_security_group_ids = ["sg-0df221bb3008fac00"]

  tags = {
    owner = "estf"
    Name ="ESTF Liza Test Instance"
    divison = "engineering"
    org = "appex"
    team = "kibana"
    project = "support_matrix"
    engineer = "liza_dayoub"
  }

  volume_tags = {
    owner = "estf"
  }
}

output "IP" {
  value = "${aws_instance.default.*.public_ip}"
}

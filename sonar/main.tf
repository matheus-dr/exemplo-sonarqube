terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region  = "sa-east-1"
  profile = "default"
}

resource "aws_key_pair" "main" {
  key_name   = "teste-sonarqube"
  public_key = file("id_rsa.pub")
}

resource "aws_security_group" "main" {
  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_instance" "main" {
  ami           = "ami-0b22b708611ed2690"
  instance_type = "t3.medium"
  key_name      = aws_key_pair.main.key_name

  vpc_security_group_ids = [aws_security_group.main.id]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("id_rsa.pem")
    host        = self.public_ip
  }

  provisioner "local-exec" {
    command = <<EOT
      sleep 60
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu -i '${self.public_ip},' --private-key 'id_rsa.pem' -e 'public_key=id_rsa.pub' playbook.yml
    EOT

    interpreter = ["/bin/bash", "-c"]
  }

  provisioner "remote-exec" {
    inline = [
      "#!/bin/bash",
      "sudo sysctl -w vm.max_map_count=524288 | sudo tee -a /etc/sysctl.conf",
      "sudo sysctl -w fs.file-max=131072 | sudo tee -a /etc/sysctl.conf",
      "ulimit -n 131072",
      "ulimit -u 8192",
      "docker-compose -f /usr/sonar/docker-compose.yml up -d"
    ]
  }
}

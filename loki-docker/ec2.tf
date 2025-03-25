resource "aws_instance" "instance" {
  ami             = "ami-0c02fb55956c7d316"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.instance_sg.name]
  key_name        = aws_key_pair.instance_kp.key_name

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/id_rsa")
    host        = self.public_ip
  }

  provisioner "file" {
    source      = "userdata.sh"
    destination = "/tmp/userdata.sh"
  }

  provisioner "file" {
    source      = "./config"
    destination = "/tmp"
    
  }

  provisioner "remote-exec" {
    inline = [
      "sed -i 's/<HOST>/${self.public_ip}/g' /tmp/config/loki-config.yml",
      "sed -i 's/<HOST>/${self.public_ip}/g' /tmp/config/promtail-config.yml",
      "sed -i 's/<HOST>/${self.public_ip}/g' /tmp/config/grafana.ini",
      "sed -i 's/<HOST>/${self.public_ip}/g' /tmp/config/loki.yaml"
    ]
    
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/userdata.sh",
      "sudo /tmp/userdata.sh"
    ]
  }

  tags = {
    Name = "instance"
  }
}

resource "aws_security_group" "instance_sg" {
  name = "instance_sg"
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "ALL"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "instance_kp" {
  key_name   = "instance_kp"
  public_key = file("~/.ssh/id_rsa.pub")
}
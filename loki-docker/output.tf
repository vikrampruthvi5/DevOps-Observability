output "instance_ip" {
  value = {
    "IP" : aws_instance.instance.public_ip
  }
}
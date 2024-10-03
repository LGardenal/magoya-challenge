output "instance_public_ip" {
  description = "Public IP of the instance"
  value       = aws_instance.ec2_instance.public_ip 
}
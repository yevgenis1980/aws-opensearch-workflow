
# -----------------------------
#      EC2 INSTANCES GROUP
# -----------------------------
resource "aws_key_pair" "ubuntu" {
  key_name   = "ubuntu"
  public_key = file("~/.ssh/id_rsa.pub") # replace with your actual public key path
}

resource "aws_launch_template" "asg_lt" {

  depends_on = [aws_key_pair.ubuntu]
  name_prefix   = "asg-lt-"
  image_id      = "ami-0345dd2cef523536e" # Amazon Ubuntu (us-west-2)
  instance_type = "t2.medium"
  key_name      = "ubuntu" # change this

  vpc_security_group_ids = [aws_security_group.asg_sg.id]

  user_data = base64encode(<<EOF
#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

apt update -y
apt install -y apache2 php php-mysql wget unzip curl nfs-common
systemctl enable apache2
systemctl start apache2

# Download WordPress
cd /var/www/html
rm -rf *.html # Test
wget https://wordpress.org/latest.zip
unzip latest.zip
mv wordpress/* .
rm -rf wordpress latest.zip

systemctl restart apache2
EOF
  )

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = 10
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "asg-instance" }
  }
}

# -----------------------------
#       EC2 AUTOSCALING
# -----------------------------
resource "aws_autoscaling_group" "asg" {
  depends_on = [aws_launch_template.asg_lt]
  name             = "app-asg"
  min_size         = 1
  max_size         = 7
  desired_capacity = 1

  vpc_zone_identifier = aws_subnet.public[*].id

  launch_template {
    id      = aws_launch_template.asg_lt.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "asg-instance"
    propagate_at_launch = true
  }
}

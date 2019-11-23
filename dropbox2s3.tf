
resource "aws_iam_policy" "dropbox2s3" {
  name        = "dropbox2s3_s3_policy"
  path        = "/"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:PutAccountPublicAccessBlock",
                "s3:GetAccountPublicAccessBlock",
                "s3:ListAllMyBuckets",
                "s3:ListJobs",
                "s3:CreateJob",
                "s3:HeadBucket"
            ],
            "Resource": "*"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::${local.destination_bucket}",
                "arn:aws:s3:::${local.destination_bucket}/*",
                "arn:aws:s3:*:*:job/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role" "dropbox2s3" {
  name = "dropbox2s3"
  description           = "Allows EC2 instances to call AWS services on your behalf."
  force_detach_policies = true
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = "${aws_iam_role.dropbox2s3.name}"
  policy_arn = "${aws_iam_policy.dropbox2s3.arn}"
}

resource "aws_iam_instance_profile" "dropbox2s3" {
  name = "dropbox2s3"
  role = "${aws_iam_role.dropbox2s3.name}"
  depends_on = [ aws_iam_role.dropbox2s3 ]
}

data "aws_ami" "ami" {
  most_recent = true
    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
    }

    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }

    owners = ["099720109477"] # Canonical
}

resource "aws_security_group" "dropbox2s3" {
  name        = "dropbox2s3"
  description = "Allow ssh from the specified IPs"

  ingress { # only allow ssh
    protocol = "tcp"
    from_port = 22
    to_port = 22
    cidr_blocks = local.source_ip_ssh
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "keypair" {
  key_name   = "dropbox2s3"
  public_key = "${local.ssh_public_key}"
}

resource "aws_instance" "instance" {
  ami           = "${data.aws_ami.ami.id}"
  instance_type = local.ec2_instance_type
  key_name = "${aws_key_pair.keypair.key_name}"
  iam_instance_profile = "${aws_iam_instance_profile.dropbox2s3.name}"

  tags = {
    Name = "dropbox2s3"
  }  
  associate_public_ip_address = true
  vpc_security_group_ids = [ "${aws_security_group.dropbox2s3.id}"]
  root_block_device {
  	volume_type = "standard"
  	volume_size = "${local.disk_size_gb}"
  	delete_on_termination = true
  	encrypted = true
  }

  depends_on = [aws_iam_instance_profile.dropbox2s3]
}


 output "ec2_hostname" {
   value = "Hostname: ${aws_instance.instance.public_dns}"
 }

 output "ssh_cmd" {
   value = "ssh command: ssh -i sshkey ubuntu@${aws_instance.instance.public_dns}"
 }
 output "ec2_instance_id" {
   value = "Instance ID: ${aws_instance.instance.id}"
 }
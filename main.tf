# AWS infrastructure using Terraform, including networking, security, EC2 instances, load balancing, auto scaling,
# monitoring, and CI/CD pipeline integration with GitHub, CodeBuild, and CodeDeploy.

provider "aws" {
  region = "eu-west-1"
} #provider "aws": Specifies that Terraform will use AWS as the cloud provider. 
  #region "eu-west-1": Sets the AWS region to Ireland.

data "aws_availability_zones" "available" {}
  # Fetches the list of available availability zones in the specified region.

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
} #Retrieves the latest Ubuntu 22.04 AMI (Amazon Machine Image) owned by Canonical (owner ID 099720109477).Filters by name and virtualization type (hvm).

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "main-vpc" }
} #Creates a VPC (Virtual Private Cloud) with a CIDR block of

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "main-igw" }
} #Creates an Internet Gateway and attaches it to the VPC created earlier.

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet-${count.index}" }
} #Creates two public subnets in the VPC, each in a different availability zone. The CIDR blocks are derived from the VPC's CIDR block.

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "public-route-table" }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
} #Creates a route table for the VPC with a default route (0.0.0.0/0) pointing to the Internet Gateway.

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
} #Associates each public subnet with the public route table.

resource "aws_iam_instance_profile" "ec2_codedeploy_profile" {
  name = "ec2-codedeploy-profile-new"
  role = aws_iam_role.ec2_codedeploy_role.name
} #Creates an IAM instance profile for the EC2 instances to be used with CodeDeploy

resource "aws_iam_role" "ec2_codedeploy_role" {
  name = "ec2-codedeploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
} #Creates an IAM role that allows EC2 instances to assume the role.

resource "aws_iam_role_policy" "ec2_codedeploy_policy" {
  name = "ec2-codedeploy-policy"
  role = aws_iam_role.ec2_codedeploy_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      Resource = "*"
    }]
  })
} #Attaches a policy to the EC2 CodeDeploy role that allows it to access S3 buckets and objects (necessary for fetching deployment artifacts from S3

resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg"
  description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
} #Creates a security group for the EC2 instances that allows inbound HTTP (port 80) and SSH (port 22) traffic from anywhere, and allows all outbound traffic.

resource "aws_launch_template" "html_template" {
  name_prefix   = "html-launch-template-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 8
      volume_type = "gp3"
      delete_on_termination = true
    }
  } #Defines the root EBS volume for the instances with a size of 8 GB, type gp3, and set to delete on termination.

  user_data = base64encode(<<-EOF
#!/bin/bash
apt update -y
apt install -y nginx ruby-full wget awscli

cd /tmp
wget https://aws-codedeploy-eu-west-1.s3.eu-west-1.amazonaws.com/latest/install
chmod +x ./install
./install auto

mkdir -p /var/www/html
chown www-data:www-data /var/www/html

systemctl start nginx
systemctl enable nginx
systemctl start codedeploy-agent
systemctl enable codedeploy-agent
EOF
  )
  
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_codedeploy_profile.name
  } # Associates the IAM instance profile with the EC2 instances.

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "HTMLAppInstance"
    }
  }
}# Creates a launch template for the EC2 instances with the specified AMI, instance type, security group, block device mapping, user data script, IAM instance profile, and tags.

resource "aws_autoscaling_group" "html_asg" {
  name                      = "html-asg"
  max_size                  = 3
  min_size                  = 2
  desired_capacity          = 2
  vpc_zone_identifier       = aws_subnet.public[*].id

  launch_template {
    id      = aws_launch_template.html_template.id
    version = "$Latest"
  }

  target_group_arns         = [aws_lb_target_group.app_tg_1.arn, aws_lb_target_group.app_tg_2.arn]

  tag {
    key                 = "Name"
    value               = "HTMLAppInstance"
    propagate_at_launch = true
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300
  force_delete              = true
}# Creates an Auto Scaling group with a minimum of 2 and a maximum of 3 instances, using the launch template defined earlier. 
# The instances are launched in the public subnets and associated with two target groups for load balancing.

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP traffic for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
} # Creates a security group for the Application Load Balancer (ALB) that allows inbound HTTP (port 80) traffic from anywhere, and allows all outbound traffic.

resource "aws_lb" "app_alb" {
  name               = "app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id
  tags = { Name = "app-alb" }
} # Creates an Application Load Balancer (ALB) with the specified settings.

resource "aws_lb_target_group" "app_tg_1" {
  name     = "app-tg-1"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
}# Creates the first target group for the ALB with health check settings.

resource "aws_lb_target_group" "app_tg_2" {
  name     = "app-tg-2"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
} # creates the second target group for the ALB with health check settings.

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.app_tg_1.arn
        weight = 50
      }
      target_group {
        arn    = aws_lb_target_group.app_tg_2.arn
        weight = 50
      }
    }
  }
} # create a listener for the ALB that listens on port 80 and forwards traffic to both target groups with equal weight.

resource "random_id" "suffix" {
  byte_length = 4
} #Generates a random suffix to ensure unique S3 bucket names.

resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket = "pipeline-artifacts-bucket-${random_id.suffix.hex}"
}# Creates an S3 bucket to store CodePipeline artifacts, using the random suffix to ensure uniqueness.

resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = [
        "codepipeline.amazonaws.com",
        "codebuild.amazonaws.com",
        "codedeploy.amazonaws.com"
      ] },
      Action = "sts:AssumeRole"
    }]
  })
} #Creates an IAM role for CodePipeline with trust relationships allowing CodePipeline, CodeBuild, and CodeDeploy to assume the role.

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline-policy"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild",
        "codedeploy:CreateDeployment",
        "codedeploy:GetApplication",
        "codedeploy:GetApplicationRevision",
        "codedeploy:GetDeployment",
        "codedeploy:GetDeploymentConfig",
        "codedeploy:RegisterApplicationRevision",
        "codestar-connections:UseConnection",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "s3:GetBucketVersioning",
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:PutObject"
      ],
      Resource = "*"
    }]
  })
} #create a IAM policy that grants the necessary permissions for CodePipeline to interact with CodeBuild, CodeDeploy, CodeStar Connections, CloudWatch Logs, and S3.

variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
  default     = "NunnaRupaSri"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "terraform-sample"
}

variable "github_branch" {
  description = "GitHub branch to use for source"
  type        = string
  default     = "main"
}

resource "aws_codestarconnections_connection" "github" {
  name          = "github-connection"
  provider_type = "GitHub"
}

resource "aws_codepipeline" "app_pipeline" {
  name     = "app-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "GitHub_Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = "${var.github_owner}/${var.github_repo}"
        BranchName       = var.github_branch
      }
    }
  } # Defines the source stage of the pipeline, which pulls code from a GitHub repository using CodeStar Connections.

  stage {
    name = "Build"
    action {
      name             = "CodeBuild"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.app_build_project.name
      }
    }
  } # Defines the build stage of the pipeline, which uses CodeBuild to build the application. It takes the source output as input and produces build output.

  stage {
    name = "Deploy"
    action {
      name            = "CodeDeploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ApplicationName     = aws_codedeploy_app.app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.app_deployment_group_new.deployment_group_name
      }
    }
  }
} # Defines the deploy stage of the pipeline, which uses CodeDeploy to deploy the built application to the specified deployment group.

resource "aws_codebuild_project" "app_build_project" {
  name          = "app-build-project"
  description   = "Build project for HTML app"
  build_timeout = 20
  service_role  = aws_iam_role.codepipeline_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
} # Creates a CodeBuild project that uses the CodePipeline role for permissions.

resource "aws_iam_role" "codedeploy_service_role" {
  name = "codedeploy-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "codedeploy.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
} #creates an IAM role for CodeDeploy with a trust relationship allowing CodeDeploy to assume the role.

resource "aws_iam_role_policy_attachment" "codedeploy_service_role_policy" {
  role       = aws_iam_role.codedeploy_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
} # Attaches the AWSCodeDeployRole managed policy to the CodeDeploy service role, granting it the necessary permissions to perform deployments.

resource "aws_iam_role_policy_attachment" "codebuild_service_role_policy" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
} # Attaches the AWSCodeBuildDeveloperAccess managed policy to the CodePipeline role, granting it permissions to interact with CodeBuild.



resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.html_asg.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 900
  autoscaling_group_name = aws_autoscaling_group.html_asg.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "high-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "50"
  alarm_description   = "Scale up when CPU exceeds 50%"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn, aws_sns_topic.alarm_topic.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.html_asg.name
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "low-cpu-utilization"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "20"
  alarm_description   = "Scale down when CPU below 20%"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.html_asg.name
  }
}

resource "aws_sns_topic" "alarm_topic" {
  name = "cpu-alarm-notifications"
}

resource "aws_sns_topic_subscription" "email_notification" {
  topic_arn = aws_sns_topic.alarm_topic.arn
  protocol  = "email"
  endpoint  = "rupa-sri.nunna@capgemini.com"
}

resource "aws_cloudwatch_event_rule" "alarm_rule" {
  name        = "cpu-alarm-state-change"
  description = "Capture CloudWatch alarm state changes"

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    detail = {
      alarmName = [aws_cloudwatch_metric_alarm.cpu_high.alarm_name, aws_cloudwatch_metric_alarm.cpu_low.alarm_name]
    }
  })
}

resource "aws_cloudwatch_event_target" "sns_target" {
  rule      = aws_cloudwatch_event_rule.alarm_rule.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.alarm_topic.arn
}

resource "aws_sns_topic_policy" "alarm_topic_policy" {
  arn = aws_sns_topic.alarm_topic.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action   = "SNS:Publish"
      Resource = aws_sns_topic.alarm_topic.arn
    }]
  })
}

resource "aws_sns_topic" "deployment_topic" {
  name = "codedeploy-notifications"
}

resource "aws_sns_topic_subscription" "deployment_email" {
  topic_arn = aws_sns_topic.deployment_topic.arn
  protocol  = "email"
  endpoint  = "rupa-sri.nunna@capgemini.com"
}

resource "aws_cloudwatch_event_rule" "codedeploy_rule" {
  name        = "codedeploy-state-change"
  description = "Capture CodeDeploy deployment state changes"

  event_pattern = jsonencode({
    source      = ["aws.codedeploy"]
    detail-type = ["CodeDeploy Deployment State-change Notification"]
    detail = {
      state = ["SUCCESS", "FAILURE", "STOPPED"]
    }
  })
}

resource "aws_cloudwatch_event_target" "deployment_sns_target" {
  rule      = aws_cloudwatch_event_rule.codedeploy_rule.name
  target_id = "SendDeploymentToSNS"
  arn       = aws_sns_topic.deployment_topic.arn
}

resource "aws_sns_topic_policy" "deployment_topic_policy" {
  arn = aws_sns_topic.deployment_topic.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action   = "SNS:Publish"
      Resource = aws_sns_topic.deployment_topic.arn
    }]
  })
}

resource "aws_codedeploy_app" "app" {
  name             = "html-app"
  compute_platform = "Server"
} # Creates a CodeDeploy application named "html-app" that targets server instances.

resource "aws_codedeploy_deployment_group" "app_deployment_group_new" {
  app_name              = aws_codedeploy_app.app.name
  deployment_group_name = "html-app-deployment-group-v2"
  service_role_arn      = aws_iam_role.codedeploy_service_role.arn

  ec2_tag_filter {
    key   = "Name"
    type  = "KEY_AND_VALUE"
    value = "HTMLAppInstance"
  }

  deployment_config_name = "CodeDeployDefault.OneAtATime"
} # Creates a CodeDeploy deployment group associated with the "html-app" application.
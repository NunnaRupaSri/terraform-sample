provider "aws" {
  region = "eu-west-1"
}

data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "main-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "main-igw" }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet-${count.index}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "public-route-table" }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
resource "aws_iam_instance_profile" "ec2_codedeploy_profile" {
  name = "ec2-codedeploy-profile"
  role = aws_iam_role.ec2_codedeploy_role.name
}
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
}
resource "aws_iam_role_policy" "ec2_codedeploy_policy" {
  name = "ec2-codedeploy-policy"
  role = aws_iam_role.ec2_codedeploy_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:Get*",
          "s3:List*",
          "codedeploy:PutLifecycleEventHookExecutionStatus",
          "codedeploy:UpdateDeploymentGroup",
          "codedeploy:GetDeploymentGroup",
          "codedeploy:GetDeployment",
          "codedeploy:RegisterApplicationRevision",
          "codedeploy:GetApplicationRevision"
        ],
        Resource = "*"
      }
    ]
  })
}
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
}
resource "aws_launch_template" "nodejs_template" {
  name_prefix   = "nodejs-launch-template-"
  image_id      = "ami-0bc691261a82b32bc"
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  user_data              = filebase64("user_data.sh")
  
iam_instance_profile {
    name = aws_iam_instance_profile.ec2_codedeploy_profile.name
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "NodeJSAppInstance"
    }
  }
}

resource "aws_autoscaling_group" "nodejs_asg" {
  name                      = "nodejs-asg"
  max_size                  = 3
  min_size                  = 2
  desired_capacity          = 2
  vpc_zone_identifier       = aws_subnet.public[*].id

  launch_template {
    id      = aws_launch_template.nodejs_template.id
    version = "$Latest"
  }

  target_group_arns         = [aws_lb_target_group.app_tg.arn]

  tag {
    key                 = "Name"
    value               = "NodeJSAppInstance"
    propagate_at_launch = true
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300
  force_delete              = true
}

resource "aws_lb" "app_alb" {
  name               = "app-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.public[*].id
  tags = { Name = "app-alb" }
}

resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_alarm" {
  alarm_name          = "high-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Alarm when CPU exceeds 70%"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.nodejs_asg.name
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket = "pipeline-artifacts-bucket-${random_id.suffix.hex}"
}

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
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline-policy"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "codebuild:*",
        "codedeploy:*",
        "codepipeline:*",
        "codestar-connections:UseConnection",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "s3:*",
        "ec2:*",
        "iam:PassRole"
      ],
      Resource = "*"
    }]
  })
}

variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
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
  }

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
  }
}

resource "aws_cloudwatch_log_group" "codebuild_log_group" {
  name              = "/aws/codebuild/app-build-project"
  retention_in_days = 14
}

resource "aws_codebuild_project" "app_build_project" {
  name          = "app-build-project"
  description   = "Build project for Node.js app"
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

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.codebuild_log_group.name
    }
  }
}

resource "aws_codedeploy_app" "app" {
  name             = "nodejs-app"
  compute_platform = "Server"
}

resource "aws_codedeploy_deployment_group" "app_deployment_group" {
  app_name              = aws_codedeploy_app.app.name
  deployment_group_name = "nodejs-app-deployment-group"
  service_role_arn      = aws_iam_role.codepipeline_role.arn

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = "NodeJSAppInstance"
    }
  }

  deployment_config_name = "CodeDeployDefault.OneAtATime"
}

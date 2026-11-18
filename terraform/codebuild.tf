locals {
  codebuild_enabled = var.github_repo_url != ""
  account_id        = data.aws_caller_identity.current.account_id
}

data "aws_caller_identity" "current" {}

resource "aws_cloudwatch_log_group" "codebuild" {
  count             = local.codebuild_enabled ? 1 : 0
  name              = "/aws/codebuild/${local.prefix}-image-build"
  retention_in_days = var.log_retention_days
}

data "aws_iam_policy_document" "codebuild_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codebuild" {
  count              = local.codebuild_enabled ? 1 : 0
  name               = "${local.prefix}-codebuild-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json
}

data "aws_iam_policy_document" "codebuild" {
  count = local.codebuild_enabled ? 1 : 0

  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.codebuild[0].arn}:*"]
  }

  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_role_policy" "codebuild" {
  count  = local.codebuild_enabled ? 1 : 0
  name   = "${local.prefix}-codebuild"
  role   = aws_iam_role.codebuild[0].id
  policy = data.aws_iam_policy_document.codebuild[0].json
}

# A private repo needs a GitHub connection authorised once in the Console (CodeBuild, Settings).
# A new account may also have a concurrent-build quota of 0: request an increase in Service Quotas.
resource "aws_codebuild_project" "image" {
  count          = local.codebuild_enabled ? 1 : 0
  name           = "${local.prefix}-image-build"
  service_role   = aws_iam_role.codebuild[0].arn
  build_timeout  = 30
  source_version = var.github_branch

  source {
    type            = "GITHUB"
    location        = var.github_repo_url
    git_clone_depth = 1
    buildspec       = <<-EOT
      version: 0.2
      phases:
        pre_build:
          commands:
            - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
        build:
          commands:
            - docker build --build-arg FORCE_HTTPS=$FORCE_HTTPS --build-arg NEXT_PUBLIC_GA_ID="" -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/${aws_ecr_repository.app.name}:$IMAGE_TAG .
        post_build:
          commands:
            - docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/${aws_ecr_repository.app.name}:$IMAGE_TAG
    EOT
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    type            = "LINUX_CONTAINER"
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    privileged_mode = true

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = local.account_id
    }
    environment_variable {
      name  = "IMAGE_TAG"
      value = var.image_tag
    }
    environment_variable {
      name  = "FORCE_HTTPS"
      value = var.force_https
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.codebuild[0].name
    }
  }
}

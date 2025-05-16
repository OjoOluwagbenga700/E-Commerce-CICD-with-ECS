# IAM role for CodeDeploy
resource "aws_iam_role" "codedeploy_role" {
  name = "e-commerce-codedeploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      }
    ]
  })
}

# Attach AWS managed policy for CodeDeploy
resource "aws_iam_role_policy_attachment" "codedeploy_policy_attachment" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
  }

  # CodeDeploy application
resource "aws_codedeploy_app" "e_commerce_app" {
  name             = "e-commerce-app"
  compute_platform = "ECS"
}

# CodeDeploy deployment group
resource "aws_codedeploy_deployment_group" "e_commerce_deployment_group" {
  app_name               = aws_codedeploy_app.e_commerce_app.name
  deployment_group_name  = "e-commerce-deployment-group"
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  service_role_arn       = aws_iam_role.codedeploy_role.arn

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.cluster.name
    service_name = aws_ecs_service.ecs_service.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.alb_https_listener.arn]
      }

      target_group {
        name = aws_lb_target_group.alb_tg.name
      }

      target_group {
        name = aws_lb_target_group.alb_tg_blue.name
      }
    }
  }
}

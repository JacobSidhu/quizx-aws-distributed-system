# ==============================================================================
# IAM policy documents
# ==============================================================================
# Policy JSON is kept as HCL objects in locals and wrapped by the resources in
# iam-policies.tf. Keeping documents separate from resources makes the actual
# permissions easy to review on their own.
#
# Least-privilege techniques used throughout:
#   - Region lock:  aws:RequestedRegion / ec2:Region = the deployment region
#   - Name scope:   resources must match "<project>-<environment>-*"
#   - Tag scope:    aws:RequestTag / aws:ResourceTag must carry the project's
#                   Project, Environment, and ManagedBy tags
#   - PassRole:     only the bootstrap EKS roles, only to EKS or EC2
# ==============================================================================
locals {
  # ----------------------------------------------------------------------------
  # Terraform caller (attached to the IAM user)
  # ----------------------------------------------------------------------------
  # The minimum the caller needs before assuming the execution role: list and
  # read/write the two state objects and their lock files, assume the role,
  # and run a few tag-scoped deployment checks.
  # ----------------------------------------------------------------------------
  terraform_caller_policy_document = {
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListBootstrapStatePath"
        Action   = "s3:ListBucket"
        Effect   = "Allow"
        Resource = "arn:aws:s3:::${var.tf_bootstrap_state_bucket_name}"
        Condition = {
          StringEquals = {
            "s3:prefix" = [
              var.tf_bootstrap_state_key,
              "${var.tf_bootstrap_state_key}.tflock"
            ]
          }
        }
      },
      {
        Sid      = "ListMainStatePath"
        Action   = "s3:ListBucket"
        Effect   = "Allow"
        Resource = "arn:aws:s3:::${local.main_state_bucket_name}"
        Condition = {
          StringEquals = {
            "s3:prefix" = [
              var.tf_main_state_key,
              "${var.tf_main_state_key}.tflock"
            ]
          }
        }
      },
      {
        Sid = "ReadWriteTerraformState"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::${var.tf_bootstrap_state_bucket_name}/${var.tf_bootstrap_state_key}",
          "arn:aws:s3:::${local.main_state_bucket_name}/${var.tf_main_state_key}"
        ]
      },
      {
        # S3-native state locking (backend use_lockfile = true) creates the
        # lock object at the start of a run and deletes it at the end.
        Sid = "ManageTerraformStateLocks"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::${var.tf_bootstrap_state_bucket_name}/${var.tf_bootstrap_state_key}.tflock",
          "arn:aws:s3:::${local.main_state_bucket_name}/${var.tf_main_state_key}.tflock"
        ]
      },
      {
        Sid      = "AssumeTerraformExecutionRole"
        Action   = "sts:AssumeRole"
        Effect   = "Allow"
        Resource = aws_iam_role.terraform_execution.arn
      },
      {
        Sid      = "WaitForManagedCertificate"
        Action   = "acm:DescribeCertificate"
        Effect   = "Allow"
        Resource = "arn:aws:acm:${var.aws_region}:${var.aws_account_id}:certificate/*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project"     = var.project_name
            "aws:ResourceTag/Environment" = var.environment
            "aws:ResourceTag/ManagedBy"   = var.managedby
          }
        }
      },
      {
        Sid      = "DiscoverSecurityGroupsForDeployment"
        Action   = "ec2:DescribeSecurityGroups"
        Effect   = "Allow"
        Resource = "*"
        Condition = {
          StringEquals = {
            "ec2:Region" = var.aws_region
          }
        }
      },
      {
        Sid = "ManageTemporaryDeploymentSshRules"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:security-group/*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project"     = var.project_name
            "aws:ResourceTag/Environment" = var.environment
            "aws:ResourceTag/ManagedBy"   = var.managedby
          }
        }
      }
    ]
  }

  # ----------------------------------------------------------------------------
  # Execution role: EC2 and VPC networking
  # ----------------------------------------------------------------------------
  # Describe calls cannot be resource-scoped in IAM, so they are allowed on
  # "*". All mutating calls are locked to the deployment region.
  # ----------------------------------------------------------------------------
  terraform_execution_ec2_policy_document = {
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEc2ReadOnlyDiscovery"
        Effect = "Allow"
        Action = [
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceAttribute",
          "ec2:DescribeInstanceCreditSpecifications",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroupRules",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeTags",
          "ec2:DescribeVpcAttribute",
          "ec2:DescribeVolumes",
          "ec2:DescribeVpcs"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowEc2ProvisioningInDeploymentRegion"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:TerminateInstances",
          "ec2:ModifyInstanceAttribute",
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:ModifyVpcAttribute",
          "ec2:CreateSubnet",
          "ec2:DeleteSubnet",
          "ec2:ModifySubnetAttribute",
          "ec2:CreateInternetGateway",
          "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:CreateRouteTable",
          "ec2:DeleteRouteTable",
          "ec2:CreateRoute",
          "ec2:DeleteRoute",
          "ec2:ReplaceRoute",
          "ec2:ReplaceRouteTableAssociation",
          "ec2:AssociateRouteTable",
          "ec2:DisassociateRouteTable",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:ModifySecurityGroupRules",
          "ec2:ImportKeyPair",
          "ec2:DeleteKeyPair",
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ec2:Region" = var.aws_region
          }
        }
      }
    ]
  }

  # ----------------------------------------------------------------------------
  # Execution role: Elastic Load Balancing (ALB)
  # ----------------------------------------------------------------------------
  terraform_execution_elbv2_policy_document = {
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowElbv2ProvisioningInDeploymentRegion"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:DescribeListenerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:ModifyListenerAttributes",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteRule",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:ModifyRule",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags",
          "elasticloadbalancing:DescribeTags"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      }
    ]
  }

  # ----------------------------------------------------------------------------
  # Execution role: API Gateway
  # ----------------------------------------------------------------------------
  # API Gateway authorises by HTTP verb on resource paths, so access is granted
  # per verb and locked to the deployment region.
  # ----------------------------------------------------------------------------
  terraform_execution_apigateway_policy_document = {
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowApiGatewayProvisioningInDeploymentRegion"
        Effect = "Allow"
        Action = [
          "apigateway:GET",
          "apigateway:POST",
          "apigateway:PUT",
          "apigateway:PATCH",
          "apigateway:DELETE",
          "apigateway:TagResource",
          "apigateway:UntagResource"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      }
    ]
  }

  # ----------------------------------------------------------------------------
  # Execution role: ECR repositories
  # ----------------------------------------------------------------------------
  # Repository management only (no image push or pull), limited to
  # repositories named "<project>-<environment>-*".
  # ----------------------------------------------------------------------------
  terraform_execution_ecr_policy_document = {
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ManageECRRepositories"
        Effect = "Allow"

        Action = [
          "ecr:CreateRepository",
          "ecr:DeleteRepository",
          "ecr:DescribeRepositories",
          "ecr:TagResource",
          "ecr:UntagResource",
          "ecr:ListTagsForResource",
          "ecr:PutLifecyclePolicy",
          "ecr:GetLifecyclePolicy",
          "ecr:DeleteLifecyclePolicy",
          "ecr:PutImageScanningConfiguration",
          "ecr:PutImageTagMutability",
          "ecr:GetRepositoryPolicy",
          "ecr:SetRepositoryPolicy",
          "ecr:DeleteRepositoryPolicy"
        ]

        Resource = "arn:aws:ecr:${var.aws_region}:${var.aws_account_id}:repository/${local.name_prefix}-*"
      }
    ]
  }

  # ----------------------------------------------------------------------------
  # Execution role: ACM certificates
  # ----------------------------------------------------------------------------
  # New certificates must be requested with the project tags, and existing ones
  # can only be managed if they carry those tags.
  # ----------------------------------------------------------------------------
  terraform_execution_acm_policy_document = {
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RequestTaggedCertificates"
        Effect = "Allow"
        Action = [
          "acm:RequestCertificate",
          "acm:AddTagsToCertificate"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Project"     = var.project_name
            "aws:RequestTag/Environment" = var.environment
            "aws:RequestTag/ManagedBy"   = var.managedby
            "aws:RequestedRegion"        = var.aws_region
          }
        }
      },
      {
        Sid    = "ManageTaggedCertificates"
        Effect = "Allow"
        Action = [
          "acm:DescribeCertificate",
          "acm:DeleteCertificate",
          "acm:AddTagsToCertificate",
          "acm:RemoveTagsFromCertificate",
          "acm:ListTagsForCertificate"
        ]
        Resource = "arn:aws:acm:${var.aws_region}:${var.aws_account_id}:certificate/*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project"     = var.project_name
            "aws:ResourceTag/Environment" = var.environment
            "aws:ResourceTag/ManagedBy"   = var.managedby
          }
        }
      },
      {
        Sid      = "ListCertificatesInDeploymentRegion"
        Effect   = "Allow"
        Action   = "acm:ListCertificates"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      }
    ]
  }

  # ----------------------------------------------------------------------------
  # Execution role: service-linked roles for ELB and API Gateway
  # ----------------------------------------------------------------------------
  # AWS creates these roles the first time each service is used in an account.
  # The statement allows only these two exact roles.
  # ----------------------------------------------------------------------------
  terraform_execution_service_linked_roles_policy_document = {
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CreateRequiredServiceLinkedRoles"
        Effect = "Allow"
        Action = "iam:CreateServiceLinkedRole"
        Resource = [
          "arn:aws:iam::${var.aws_account_id}:role/aws-service-role/elasticloadbalancing.amazonaws.com/AWSServiceRoleForElasticLoadBalancing",
          "arn:aws:iam::${var.aws_account_id}:role/aws-service-role/ops.apigateway.amazonaws.com/AWSServiceRoleForAPIGateway"
        ]
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = [
              "elasticloadbalancing.amazonaws.com",
              "ops.apigateway.amazonaws.com"
            ]
          }
        }
      }
    ]
  }

  # ----------------------------------------------------------------------------
  # Execution role: SQS queues
  # ----------------------------------------------------------------------------
  # Queue lifecycle only (create, configure, delete), never message access.
  # Creation requires the project tags.
  # ----------------------------------------------------------------------------
  terraform_execution_sqs_policy_document = {
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CreateTaggedProjectQueues"
        Effect = "Allow"
        Action = [
          "sqs:CreateQueue",
          "sqs:TagQueue"
        ]
        Resource = "arn:aws:sqs:${var.aws_region}:${var.aws_account_id}:${local.name_prefix}-*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Project"     = var.project_name
            "aws:RequestTag/Environment" = var.environment
            "aws:RequestTag/ManagedBy"   = var.managedby
          }
        }
      },
      {
        Sid    = "ManageTaggedProjectQueues"
        Effect = "Allow"
        Action = [
          "sqs:DeleteQueue",
          "sqs:GetQueueAttributes",
          "sqs:ListQueueTags",
          "sqs:SetQueueAttributes",
          "sqs:TagQueue",
          "sqs:UntagQueue"
        ]
        Resource = "arn:aws:sqs:${var.aws_region}:${var.aws_account_id}:${local.name_prefix}-*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      }
    ]
  }

  # ----------------------------------------------------------------------------
  # Execution role: RDS service-linked role
  # ----------------------------------------------------------------------------
  terraform_execution_rds_service_linked_role_policy_document = {
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "CreateRdsServiceLinkedRole"
        Effect   = "Allow"
        Action   = "iam:CreateServiceLinkedRole"
        Resource = "arn:aws:iam::${var.aws_account_id}:role/aws-service-role/rds.amazonaws.com/AWSServiceRoleForRDS"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "rds.amazonaws.com"
          }
        }
      }
    ]
  }

  # ----------------------------------------------------------------------------
  # Execution role: VPC endpoints
  # ----------------------------------------------------------------------------
  # Endpoint lifecycle plus the describe calls it depends on. Locked to the
  # deployment region.
  # ----------------------------------------------------------------------------
  terraform_execution_vpc_endpoint_policy_document = {
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ManageVpcEndpoints"
        Effect = "Allow"

        Action = [
          "ec2:CreateVpcEndpoint",
          "ec2:ModifyVpcEndpoint",
          "ec2:DeleteVpcEndpoints",
          "ec2:DescribeVpcEndpoints",
          "ec2:DescribeVpcEndpointServices",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribePrefixLists",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]

        Resource = "*"

        Condition = {
          StringEquals = {
            "ec2:Region" = var.aws_region
          }
        }
      }
    ]
  }

  # ----------------------------------------------------------------------------
  # Execution role: RDS
  # ----------------------------------------------------------------------------
  # DB instances, subnet groups, and snapshots in this account and region.
  # ----------------------------------------------------------------------------
  terraform_execution_rds_policy_document = {
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DescribeRDSResources"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBSubnetGroups",
          "rds:DescribeDBSnapshots",
          "rds:DescribeDBEngineVersions",
          "rds:DescribeOrderableDBInstanceOptions",
          "rds:DescribePendingMaintenanceActions",
          "rds:ListTagsForResource"
        ]
        Resource = "arn:aws:rds:${var.aws_region}:${var.aws_account_id}:*"
      },
      {
        Sid    = "ManageRDSResources"
        Effect = "Allow"
        Action = [
          "rds:CreateDBInstance",
          "rds:ModifyDBInstance",
          "rds:DeleteDBInstance",
          "rds:RebootDBInstance",
          "rds:CreateDBSubnetGroup",
          "rds:ModifyDBSubnetGroup",
          "rds:DeleteDBSubnetGroup",
          "rds:CreateDBSnapshot",
          "rds:DeleteDBSnapshot",
          "rds:RestoreDBInstanceFromDBSnapshot",
          "rds:AddTagsToResource",
          "rds:RemoveTagsFromResource"
        ]
        Resource = "arn:aws:rds:${var.aws_region}:${var.aws_account_id}:*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      }
    ]
  }

  # ----------------------------------------------------------------------------
  # Execution role: EKS
  # ----------------------------------------------------------------------------
  # Cluster and node group management for "<project>-<environment>-*". The
  # role may pass only the two bootstrap EKS roles, and only to EKS or EC2,
  # which blocks privilege escalation through iam:PassRole.
  # ----------------------------------------------------------------------------
  terraform_execution_eks_policy_document = {
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ManageEKSCluster"
        Effect = "Allow"

        Action = [
          "eks:CreateCluster",
          "eks:DescribeCluster",
          "eks:UpdateClusterConfig",
          "eks:UpdateClusterVersion",
          "eks:DeleteCluster",
          "eks:TagResource",
          "eks:UntagResource",
          "eks:ListTagsForResource"
        ]

        Resource = "arn:aws:eks:${var.aws_region}:${var.aws_account_id}:cluster/${local.name_prefix}-*"
      },
      {
        Sid    = "ManageEKSNodeGroups"
        Effect = "Allow"

        Action = [
          "eks:CreateNodegroup",
          "eks:DescribeNodegroup",
          "eks:UpdateNodegroupConfig",
          "eks:UpdateNodegroupVersion",
          "eks:DeleteNodegroup",
          "eks:TagResource",
          "eks:UntagResource",
          "eks:ListTagsForResource"
        ]

        Resource = [
          "arn:aws:eks:${var.aws_region}:${var.aws_account_id}:cluster/${local.name_prefix}-*",
          "arn:aws:eks:${var.aws_region}:${var.aws_account_id}:nodegroup/${local.name_prefix}-*"
        ]
      },
      {
        Sid    = "ReadEKS"
        Effect = "Allow"

        Action = [
          "eks:ListNodegroups",
          "eks:DescribeUpdate",
          "eks:ListUpdates"
        ]

        Resource = "arn:aws:eks:${var.aws_region}:${var.aws_account_id}:*"
      },
      {
        # eks:ListClusters has no resource-level permissions, so IAM only
        # matches it against Resource "*". It is region-locked instead.
        Sid      = "ListEKSClusters"
        Effect   = "Allow"
        Action   = "eks:ListClusters"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Sid    = "ReadEKSRequiredRoles"
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:ListAttachedRolePolicies"
        ]

        Resource = [
          aws_iam_role.eks_cluster.arn,
          aws_iam_role.eks_node.arn,
          "arn:aws:iam::${var.aws_account_id}:role/aws-service-role/eks.amazonaws.com/*",
          "arn:aws:iam::${var.aws_account_id}:role/aws-service-role/eks-nodegroup.amazonaws.com/*"
        ]
      },
      {
        Sid      = "CreateEKSServiceLinkedRoles"
        Effect   = "Allow"
        Action   = "iam:CreateServiceLinkedRole"
        Resource = "*"

        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = [
              "eks.amazonaws.com",
              "eks-nodegroup.amazonaws.com"
            ]
          }
        }
      },
      {
        Sid    = "PassEKSServiceRoles"
        Effect = "Allow"

        Action = "iam:PassRole"

        Resource = [
          aws_iam_role.eks_cluster.arn,
          aws_iam_role.eks_node.arn
        ]

        Condition = {
          StringEquals = {
            "iam:PassedToService" = [
              "eks.amazonaws.com",
              "ec2.amazonaws.com"
            ]
          }
        }
      }
    ]
  }
}

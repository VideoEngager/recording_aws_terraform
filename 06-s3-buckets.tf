data "aws_elb_service_account" "main" {
  region = var.deployment_region
}


resource "aws_s3_bucket" "recording_logs" {
  bucket = "recording-logs-${var.tenant_id}-${var.infrastructure_purpose}"
  acl    = "private"

  lifecycle_rule {
    id      = var.lb_prefix
    enabled = true

    prefix = var.lb_prefix

    tags = {
      "rule"      = var.lb_prefix
      "autoclean" = "true"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 60
      storage_class = "GLACIER"
    }

    expiration {
      days = 90
    }
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning {
    enabled = "true"
  }

  force_destroy = var.s3_bucket_force_destroy


  tags = {
    Name        = "recording-${var.tenant_id}-${var.infrastructure_purpose}-logs"
    Environment = var.infrastructure_purpose
  }

}



resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.recording_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}




# Attach a policy to allow firehose role access S3 bucket  
resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.recording_logs.id
  policy = data.aws_iam_policy_document.allow_s3_actions.json

  depends_on = [
    aws_s3_bucket_public_access_block.this
  ]

}


data "aws_iam_policy_document" "allow_s3_actions" {
  statement {
    effect = "Allow"

    principals {
      type = "AWS"

      identifiers = [
        data.aws_elb_service_account.main.arn
      ]
    }

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.recording_logs.arn}/*"
    ]
  }


  statement {
    effect = "Allow"

    principals {
      type = "Service"

      identifiers = [
        "delivery.logs.amazonaws.com"
      ]
    }


    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.recording_logs.arn}/*"
    ]


    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"

      values = [
        "bucket-owner-full-control"
      ]
    }
  }


  statement {
    effect = "Allow"

    principals {
      type = "Service"

      identifiers = [
        "delivery.logs.amazonaws.com"
      ]
    }

    actions = [
      "s3:GetBucketAcl"
    ]

    resources = [
      aws_s3_bucket.recording_logs.arn
    ]
  }

}
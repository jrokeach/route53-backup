### Configure variables
variable "aws_access_key" {
  type        = "string"
  description = "AWS Access Key"
}

variable "aws_secret_key" {
  type        = "string"
  description = "AWS Secret Key"
}

variable "aws_region" {
  type        = "string"
  description = "AWS Region"
  default     = "us-west-1"
}

variable "zip_file_path" {
  type        = "string"
  description = "Path to .zip file"
  default     = "route53_lambda_backup.zip"
}

variable "bucket_name" {
  type        = "string"
  description = "S3 bucket for backups"
}


# Configure the AWS Provider
provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.aws_region}"
}


# S3 Bucket
resource "aws_s3_bucket" "route53_backup_s3_bucket" {
  bucket = "${var.bucket_name}"
  acl    = "private"
}


# Lambda Function
resource "aws_lambda_function" "route53_backup_lambda_function" {
  function_name = "Route53Backup"
  filename      = "${var.zip_file_path}"
  role          = "${aws_iam_role.route53_backup_iam_role.arn}"
  handler       = "route53_lambda_backup.lambda_handler"
  runtime       = "python3.6"
  timeout       = 10

  environment {
    variables = {
      s3_bucket_name   = "${var.bucket_name}",
      s3_bucket_region = "${var.aws_region}"
    }
  }
}


# IAM Role
resource "aws_iam_role" "route53_backup_iam_role" {
  name               = "route53-lambda-backup-role"
  description        = "Route 53 Lambda backup role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}


# Route 53 Read IAM Policy
resource "aws_iam_role_policy_attachment" "attach_route53_read_only_policy" {
  role       = "${aws_iam_role.route53_backup_iam_role.id}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonRoute53ReadOnlyAccess"
}


# S3 Write IAM Policy
resource "aws_iam_role_policy" "s3_write_role_policy" {
  name   = "S3WritePolicy"
  role   = "${aws_iam_role.route53_backup_iam_role.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:CreateBucket",
                "s3:PutObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::${var.bucket_name}",
                "arn:aws:s3:::*/*"
            ]
        }
    ]
}
EOF
}
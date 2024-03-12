# eventBridgeとlambdaの連携
resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.daily_trigger.name
  target_id = "TriggerLambdaDaily"
  arn       = aws_lambda_function.lambda_cron.arn
}

resource "aws_cloudwatch_event_rule" "daily_trigger" {
  name                = "test"
  description         = "Triggers Lambda daily"
  schedule_expression = "cron(0/1 * * * ? *)" # 1分ごとに実行
}

# lambdaへのアクセス権限
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_cron.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_trigger.arn
}

data "archive_file" "lambda_binary_zip" {
  source_file = "../go/dist/bootstrap"
  output_path = "../go/dist/bootstrap.zip"
  type        = "zip"
}

# Lambda関数
resource "aws_lambda_function" "lambda_cron" {
  function_name = "test"

  filename         = data.archive_file.lambda_binary_zip.output_path
  source_code_hash = data.archive_file.lambda_binary_zip.output_base64sha256
  handler          = "bootstrap" # Goの実行可能ファイルの名前
  runtime          = "provided.al2023"
  role             = aws_iam_role.lambda_execution_role.arn
}
# Lambda関数用のIAMロール
resource "aws_iam_role" "lambda_execution_role" {
  name = "test"
  assume_role_policy = data.aws_iam_policy_document.allow_assume_role.json
}
data "aws_iam_policy_document" "allow_assume_role" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}


# Cloud watchへのログ出力
resource "aws_iam_policy" "lambda_logging" {
  name        = "test_matsuda_s3_lambda_triggger_logging_policy"
  description = "IAM policy for logging from a lambda to CloudWatch Logs"
  policy      = data.aws_iam_policy_document.lambda_logging_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

data "aws_iam_policy_document" "lambda_logging_policy" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:ap-northeast-1:*:*"]
  }
}

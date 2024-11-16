# AWSプロバイダーの設定
provider "aws" {
  region = "ap-northeast-1"
}

# Lambda IAMロールの作成
resource "aws_iam_role" "lambda_iam_role" {
  name = "location_lifelog_lambda_iam_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = { Service = "lambda.amazonaws.com" }
      }
    ]
  })
}

# Lambda IAMポリシーの作成（Amazon Location Serviceへのアクセスの許可）
resource "aws_iam_policy" "lambda_location_service_policy" {
  name = "location_lifelog_lambda_policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "geo:SearchPlaceIndexForPosition"
        ],
        Resource = "*"
      }
    ]
  })
}

# Lambdaの実行ロールに基本ポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "lambda_basic_execution_role" {
  role       = aws_iam_role.lambda_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambdaの実行ロールにDynamoDBの操作を許可するポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_full_access" {
  role       = aws_iam_role.lambda_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# Lambdaの実行ロールに独自ポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "lambda_location_service_policy" {
  role       = aws_iam_role.lambda_iam_role.name
  policy_arn = aws_iam_policy.lambda_location_service_policy.arn
}

# Lambda関数の定義
resource "aws_lambda_function" "location_lifelog_function" {
  filename      = "../function.zip"
  function_name = "location-lifelog"
  role          = aws_iam_role.lambda_iam_role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = 10
  memory_size   = 128
  ephemeral_storage {
    size = 512
  }
  source_code_hash = filebase64sha256("../function.zip") # デプロイ検知用のハッシュ値
}

# Lambda関数URLの有効化
resource "aws_lambda_function_url" "function_url" {
  function_name = aws_lambda_function.location_lifelog_function.function_name

  # 認証不要で公開アクセスを許可
  authorization_type = "NONE"
  cors {
    allow_origins = ["*"]
  }
}

# Lambda関数URLのアクセス許可設定
resource "aws_lambda_permission" "allow_function_url" {
  statement_id           = "AllowPublicAccessToFunctionURL"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.location_lifelog_function.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

# DynamoDBテーブルの作成
resource "aws_dynamodb_table" "location_lifelog_table" {
  name      = "location-lifelog"
  billing_mode = "PAY_PER_REQUEST" # オンデマンドモード
  hash_key = "datetime"  # パーティションキー
  range_key = "full_address" # ソートキー

  attribute {
    name = "datetime"
    type = "N"
  }

  attribute {
    name = "full_address"
    type = "S"
  }

  attribute {
    name = "latitude"
    type = "N"
  }

  attribute {
    name = "longitude"
    type = "N"
  }

  global_secondary_index {
    name            = "LatitudeIndex"
    hash_key        = "latitude"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "LongitudeIndex"
    hash_key        = "longitude"
    projection_type = "ALL"
  }

  # 自動バックアップをオフに設定
  point_in_time_recovery {
    enabled = false
  }

  # TTL設定なし
  ttl {
    enabled = false
  }
}

# Amazon Location ServiceのPlace Indexを作成
resource "aws_location_place_index" "location_lifelog_place_index" {
  index_name  = "location-lifelog-place-index"
  data_source = "Esri"
}

# Lambdaの実行ロールにAmazon Location Serviceへのアクセス権限を付与
resource "aws_iam_role_policy" "lambda_location_policy" {
  name = "LambdaLocationPolicy"
  role = aws_iam_role.lambda_iam_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "location:SearchPlaceIndexForPosition"
        ]
        Resource = "*"
      }
    ]
  })
}
data "terraform_remote_state" "lambda" {
  backend = "s3"
  config = {
    bucket = "fmt-project-tf-backend"
    key    = "terraform_lambda.tfstate"
    region = var.region
  }
}

# API Gateway
resource "aws_api_gateway_rest_api" "this" {
  name        = "api-gateway-${var.lambda_api_name}"
  description = "API Gateway that proxies all requests to the FastAPI Lambda function"

  # Why "regional" over "edge": https://docs.aws.amazon.com/apigateway/latest/developerguide/create-regional-api.html
  endpoint_configuration {
    types = ["REGIONAL"]
  }

  lifecycle {
    create_before_destroy = true
  }


  tags = {
    Name = "${var.lambda_api_name}-api-gateway"
  }
}

resource "aws_api_gateway_resource" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "{proxy+}" # Catch-all proxy resource and forward to lambda
}

# We forward all requests (regardless of HTTP method) to the lambda w/o authorization.
resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.this.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_method.proxy.resource_id
  http_method             = aws_api_gateway_method.proxy.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = data.terraform_remote_state.lambda.outputs.lambda_api_invoke_arn
}

resource "aws_api_gateway_method" "proxy_root" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_rest_api.this.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_root" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_method.proxy_root.resource_id
  http_method = aws_api_gateway_method.proxy_root.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = data.terraform_remote_state.lambda.outputs.lambda_api_invoke_arn
}

resource "aws_api_gateway_deployment" "this" {
  depends_on = [
    aws_api_gateway_integration.lambda,
    aws_api_gateway_integration.lambda_root,
    aws_lambda_permission.apigw,
  ]
  rest_api_id = aws_api_gateway_rest_api.this.id
  # this will create "/api" endpoint at the URL, should be also in FastAPI definition.
  stage_name = "api"
}

# Grant permission to API Gateway to invoke lambda
resource "aws_lambda_permission" "apigw" {
  function_name = data.terraform_remote_state.lambda.outputs.lambda_api_function_name
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

# Add CloudWatch connection
resource "aws_api_gateway_account" "example" {
  cloudwatch_role_arn = "arn:aws:iam::851725270120:role/role-for-api-gateway-logs"
}

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_deployment.this.stage_name
  method_path = "*/*"

  settings {
    logging_level   = "INFO"
    metrics_enabled = true
  }
}
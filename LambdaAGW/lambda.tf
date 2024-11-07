/**

Created a lambda function, define a API endpoint,
assign a role to API GW to invoke the lambda function
1. Lambda
2. Role
    Effect-allow (allow or deny)
    Action - AssumeRole (whoever assumes this role) - the performer
    Principal - service->lambda.amazonaws.com (entity on which the action s performed)
3.Role policy attachement
    Role name
    Policy arn (tells what the performer or role assumer can do on the principal)

*/

data "archive_file" "prem_lmd_zip"{
    type = "zip"
    source_file = "lambda/premTfLmd.py"
    output_path = "lamdba/premTfLmd.zip"
}


resource "aws_iam_role" "prem_lmd_x_role" {
  name = "prem-lmd-x-role"
  assume_role_policy = file("premTfLmdPolicy.json")
}

resource "aws_iam_role_policy_attachment" "prem_lmd_x_policy_attach" {
  role = aws_iam_role.prem_lmd_x_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "prem_tf_lmd" {
  function_name = "prem-tf-api-lmd"
  filename = "lambda/premTfLmd.py"
  role = aws_iam_role.prem_lmd_x_role.arn
  handler = "index.handler"
  runtime = "python3.12"
  timeout = 30
  source_code_hash = data.archive_file.prem_lmd_zip.output_base64sha256
  environment {
    variables = {
      TITLE = "Prem TF Lambda API gateway integraton"
    }
  }
}

resource "aws_api_gateway_rest_api" "prem_apigw_rest_api" {
  name = "prem-tf-apigw-resst-api"
  description = "prem api lambda"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "prem_apigw_rest_api_resource" {
  parent_id = aws_api_gateway_rest_api.prem_apigw_rest_api.root_resource_id
  path_part = "prem_path"
  rest_api_id = aws_api_gateway_rest_api.prem_apigw_rest_api.id
}

resource "aws_api_gateway_method" "prem_apigw_rest_api_method" {
  resource_id = aws_api_gateway_resource.prem_apigw_rest_api_resource.id
  rest_api_id = aws_api_gateway_rest_api.prem_apigw_rest_api.id
  http_method = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "prem_apigw_lmd_integra" {
  http_method = aws_api_gateway_method.prem_apigw_rest_api_method.http_method
  resource_id = aws_api_gateway_resource.prem_apigw_rest_api_resource.id
  rest_api_id = aws_api_gateway_rest_api.prem_apigw_rest_api.id
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = aws_lambda_function.prem_tf_lmd.arn
}

resource "aws_api_gateway_deployment" "prem_apigw_deploy" {
  rest_api_id = aws_api_gateway_rest_api.prem_apigw_rest_api.id
  stage_name = "dev"
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.prem_apigw_rest_api_resource.id,
      aws_api_gateway_method.prem_apigw_rest_api_method.id,
      aws_api_gateway_integration.prem_apigw_lmd_integra.id
    ] ) )
  }

  lifecycle {
    create_before_destroy = true
  }
  
  depends_on = [
    aws_api_gateway_integration.prem_apigw_lmd_integra
  ]
}

resource "aws_lambda_permission" "prem_apigw_lmd_permi" {
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.prem_tf_lmd.function_name
  principal = "apigateway.amazonaws.com"
  statement_id = "AllowExecutionFromAPIGateway"
  source_arn = "${aws_api_gateway_rest_api.prem_apigw_rest_api.execution_arn}/*/*/*"
}

output "invoke_url" {
  value = aws_api_gateway_deployment.prem_apigw_deploy.invoke_url
}
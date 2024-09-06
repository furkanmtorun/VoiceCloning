# questions

- Problem: During batchjob subm, 
  - How to solve?
    - AWS Recomm: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/verify-connectivity.html 
    - https://stackoverflow.com/questions/67301268/aws-fargate-resourceinitializationerror-unable-to-pull-secrets-or-registry-auth#comment125106927_67424313
    - https://stackoverflow.com/a/66545922
    - https://stackoverflow.com/a/74623372

- Terraform
   - How to avoid repetitive code blocks? Modules?
   - How to arrange best the different environments? DEV, STAGING, PROD?
       - Git branches (hate it)
       - Folder organization (what I use now)
       - Terraform workspaces (idk)


# answered:

- **Why do we need both API Gateway and CloudFront and how it works together?**
  - api gateway:
    -  API mgmt: It routes the incoming HTTPS requests to lambda function and enables versioning.
    -  Security: It can integrate AWS IAM, Cognito and identity providers
    -  Monitoring and logging
 -  CloudFront:
    - Cache and latency: CDN caches the responses, so can avoid time for the same requests & brings cached content closer to users
    - Scalability: Make it highly available by running on edge locations
    - Security: Protects from DDoS and can handle SSL/TLS protocols
    - Cost efficieny: Caching reduces to cost by not invoking the lambda
  - How it works together:
    - Client Request: A client makes a request to your API endpoint, which is routed through CloudFront.
      CloudFront Edge Cache: CloudFront checks if the requested content is cached at the edge location. If cached, it returns the response immediately.
      API Gateway Integration: If the content is not cached, CloudFront forwards the request to API Gateway.
      Lambda Execution: API Gateway routes the request to the appropriate Lambda function, which processes the request using your FastAPI application.
      Response Delivery: The response from Lambda is sent back through API Gateway to CloudFront, which caches it for future requests, and then delivers it to the client.
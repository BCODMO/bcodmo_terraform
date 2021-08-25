# laminar_terraform
Terraform scripts for laminar architecture

To update the ECR docker containers, see the deploy.sh scripts in laminar_web and laminar_server repos

Use `terraform workspace select production` to deploy to production

You will need to import the https certificate. For example:

```
terraform import aws_acm_certificate.cert arn:aws:acm:us-east-1:504672911985:certificate/7d76e817-d2dc-44e6-902c-d9cb8898e6f2
```

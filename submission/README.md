# submission_terraform
Terraform scripts for submission architecture

To update the ECR docker containers, see the deploy.sh scripts in bcodmo_submission repo 

Use `terraform workspace select production` to deploy to production

You will need to manually create the state bucket and dynamoDB table. See backend.tf file for information about those resources. After that you'll need to import those resources like:

```
terraform import aws_dynamodb_table.terraform_locks submission-terraform-locks;
terraform import aws_s3_bucket.terraform_state bcodmo-submission-terraform-state;
```

You will need to import the https certificate. For example:

```
terraform import aws_acm_certificate.cert arn:aws:acm:us-east-1:504672911985:certificate/7d76e817-d2dc-44e6-902c-d9cb8898e6f2
```

Safelist Orcids:
```
0000-0003-3781-4641 - Dana
0000-0001-9414-722X - Conrad
0000-0002-5133-5842 - Amber
0000-0002-5133-5842 - Shannon
0000-0002-1134-7347 - Danie
0000-0003-1473-8789 - Nancy
0000-0002-4602-3537 - Karen
0000-0003-4486-9448 - Adam
0000-0001-8838-8780 - Tina
0000-0002-5819-478X - Taylor

```

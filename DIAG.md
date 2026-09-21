```

[0m[1mInitializing the backend...[0m
[0m[32m
Successfully configured the backend "s3"! OpenTofu will automatically
use this backend unless the backend configuration changes.[0m

[0m[1mInitializing provider plugins...[0m
- Reusing previous version of hashicorp/aws from the dependency lock file
- Installing hashicorp/aws v6.65.0...
- Installed hashicorp/aws v6.65.0 (signed, key ID [0m[1m0C0AF313E5FD9F80[0m[0m)

Providers are signed by their developers.
If you'd like to know more about provider signing, you can read about it here:
https://opentofu.org/docs/cli/plugins/signing/

[0m[1m[32mOpenTofu has been successfully initialized![0m[32m[0m
[0m[32m
You may now begin working with OpenTofu. Try running "tofu plan" to see
any changes that are required for your infrastructure. All OpenTofu commands
should now work.

If you ever set or change modules or backend configuration for OpenTofu,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.[0m
data.aws_route53_zone.this: Reading...
aws_cloudfront_origin_access_control.this: Refreshing state... [id=E11U6OK02H9XVE]
aws_acm_certificate.this: Refreshing state... [id=arn:aws:acm:us-east-1:235494802586:certificate/489da1a6-6552-4321-84ea-e0098c61e64c]
data.aws_caller_identity.current: Reading...
data.aws_caller_identity.current: Read complete after 0s [id=235494802586]
aws_s3_bucket.site: Refreshing state... [id=platform-docs-235494802586]

Planning failed. OpenTofu encountered an error while generating this plan.


Error: listing Route 53 Hosted Zone (Z09391223FTQUOR29TCRC) tags: operation error Route 53: ListTagsForResource, https response error StatusCode: 403, RequestID: 87791ef3-863d-49c6-91d4-0fe6d18551f6, api error AccessDenied: User: arn:aws:sts::235494802586:assumed-role/todolist-dev-arc-runner-docs/1789998791699843798 is not authorized to perform: route53:ListTagsForResource on resource: arn:aws:route53:::hostedzone/Z09391223FTQUOR29TCRC because no identity-based policy allows the route53:ListTagsForResource action

  with data.aws_route53_zone.this,
  on main.tf line 3, in data "aws_route53_zone" "this":
   3: data "aws_route53_zone" "this" {


Error: reading S3 Bucket (platform-docs-235494802586) CORS configuration: operation error S3: GetBucketCors, https response error StatusCode: 403, RequestID: 735HMDXAZ493J01E, HostID: 1LDFJQmfM0ftPcU6R9wRgdh3ZFpHLzZprJn7tomCzZvkGKYKbGkD/iIBhyiilL6yfShQ++Id8Fc=, api error AccessDenied: User: arn:aws:sts::235494802586:assumed-role/todolist-dev-arc-runner-docs/1789998791699843798 is not authorized to perform: s3:GetBucketCORS on resource: "arn:aws:s3:::platform-docs-235494802586" because no identity-based policy allows the s3:GetBucketCORS action

  with aws_s3_bucket.site,
  on main.tf line 10, in resource "aws_s3_bucket" "site":
  10: resource "aws_s3_bucket" "site" {

```

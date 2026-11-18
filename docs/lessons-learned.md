# Lessons learned

The stack was first built by hand in the AWS Console to understand every resource, then rewritten as Terraform and CloudFormation. These are the problems met along the way.

## From the Console build
- **Wrong database port.** The RDS security group allowed 3006 instead of 3306, so the app waited forever for the database. In code, the port is one value and the rule references the app security group.
- **Health-check grace period of 0.** ECS killed the task before the app was ready. The service now sets a 90 second grace period.
- **Unbounded wait for the database.** The container entrypoint retries forever, so a one-off migration task could run for hours. Worth adding a retry limit in the app.
- **Secret name mismatch.** The execution role's policy named a different secret than the real one. In code, the policy references the secret resource itself, so they cannot drift apart.
- **CodeBuild concurrent-build quota of 0** on a new account. Request an increase in Service Quotas before the first build.

## From the Terraform deployment
- **Default tags need extra permissions.** Provider-level `default_tags` make Terraform tag resources on creation, which needed `application-autoscaling:TagResource`. The managed ECS policy did not include it. Read the `AccessDenied` message: it names the exact action.
- **A transient font-download failure.** The app downloads Google Fonts during `next build`, and one CodeBuild run failed with a font URL parsing error. A plain retry succeeded. Self-hosting the fonts would remove the external dependency.
- **Bootstrap order matters.** The service cannot start until an image exists and the database is migrated, so the service is created with zero tasks and scaled to one afterwards.
- **Multi-AZ RDS is the slow step.** Creating the standby takes 10 to 20 minutes; do not interrupt the apply.
- **Use MySQL 8.0, not 8.4,** unless the app passes `allowPublicKeyRetrieval`.
- **In-memory features do not scale out.** The rate limiter and cache live in each task's memory, so with more than one task the limits are per task. Move them to Redis for real use.

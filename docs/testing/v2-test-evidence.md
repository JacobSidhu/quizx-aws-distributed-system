# QuizX AWS v2.0.0 Test Evidence

Test date: 2026-08-28
Release commit tested: `740bd3f`
Branch: `feature/aws-v2`
AWS region: `eu-west-2`

## Release Scope

QuizX v2.0.0 deploys an event-driven quiz system across two AWS EC2
instances. The Submit App publishes question submissions to RabbitMQ. The ETL
consumer receives those messages, persists the data in MySQL, and makes the
submitted questions available through the Question App.

```text
Submit App -> RabbitMQ -> ETL Consumer -> MySQL -> Question App
```

## Demonstration Video

[Watch the QuizX AWS v2.0.0 end-to-end demonstration](https://drive.google.com/file/d/1oShK66vFUYSngbPsM95TE_LUGg-Pae1D/view?usp=sharing)

The video demonstrates:

- The v2 architecture and repository structure.
- Terraform and GitHub Actions deployment.
- Containers running across two EC2 instances.
- The RabbitMQ durable queue and its consumer state.
- A message being retained while the ETL consumer is stopped.
- The ETL consumer reconnecting and consuming the waiting message.
- The submitted question becoming available through the Question App.
- Security controls and current release limitations.

## Automated CI Verification

[Successful CI workflow](https://github.com/JacobSidhu/quizx-aws-distributed-system/actions/runs/33093054279)

Verified:

- Question App syntax checks.
- Submit App syntax checks.
- ETL consumer syntax checks.
- Docker image builds.
- Terraform formatting, initialization, validation, and planning.

Result: **passed**.

## AWS Deployment Verification

[Successful apply and deployment workflow](https://github.com/JacobSidhu/quizx-aws-distributed-system/actions/runs/33212881473)

Verified:

- Terraform initialized against the S3 backend.
- Terraform apply completed successfully.
- Question App and Submit App EC2 deployments passed.
- Both application health checks passed.
- The ETL consumer check passed.
- Private app-to-app integration passed.
- Temporary GitHub runner SSH rules were revoked.
- The final deployment summary passed.

Result: **passed**.

## Terraform State Verification

Terraform state was stored at:

```text
s3://quizx-terraform-state-379959319907/quizx/terraform.tfstate
```

Verified:

- S3 backend initialization succeeded.
- Bucket versioning was enabled.
- Public access was blocked.
- The remote state supported both apply and destroy operations.
- State contents were not committed or included in public evidence.

Result: **passed**.

## Runtime Container Verification

Question App EC2 containers:

- `quizx-question-app`
- `quizx-etl-consumer`
- `quizx-mysql`

Submit App EC2 containers:

- `quizx-submit-app`
- `quizx-rabbitmq`

Verified:

- All expected containers started.
- MySQL had no public host-port mapping.
- RabbitMQ contained the durable `question.submitted` queue.
- The ETL consumer connected as a RabbitMQ consumer.

Result: **passed**.

## Event-Driven Messaging Test

Test procedure:

1. Stopped `quizx-etl-consumer`.
2. Confirmed RabbitMQ reported zero consumers.
3. Submitted a new question through Submit App.
4. Confirmed Submit App reported successful queue publication.
5. Confirmed RabbitMQ contained one ready message.
6. Restarted the ETL consumer.
7. Confirmed the consumer reconnected.
8. Confirmed the RabbitMQ ready-message count returned to zero.
9. Retrieved the submitted question through Question App.

Expected result:

- RabbitMQ retains the submission while the consumer is unavailable.
- The ETL consumer processes the message after restarting.
- The question is persisted in MySQL and returned by Question App.

Actual result: **passed**.

## Security Verification

Verified:

- MySQL was not publicly exposed.
- RabbitMQ port `5672` was restricted between security groups.
- Cross-instance communication used private EC2 addresses.
- SSH was restricted by CIDR.
- GitHub runner SSH access was temporary and revoked.
- Credentials and application passwords were stored in GitHub secrets.
- No private key, `.env`, `terraform.tfvars`, plan, or state file was committed.

Result: **passed**.

## Cleanup Verification

[Successful Terraform destroy workflow](https://github.com/JacobSidhu/quizx-aws-distributed-system/actions/runs/33215256451)

Verified:

- Terraform destroy completed successfully.
- Both QuizX EC2 instances were terminated.
- Terraform-managed networking resources were removed.
- The S3 backend remained available for state history.
- No QuizX EC2 instances remained running.

Result: **passed**.

## Known Limitations

- Public application endpoints use HTTP without TLS.
- Both EC2 instances use a public subnet.
- GitHub Actions currently uses long-lived AWS access-key secrets.
- Deployment uses SSH.
- MySQL and RabbitMQ run as containers rather than managed AWS services.

Recommended future improvements include HTTPS, private application subnets, a
load balancer, GitHub OIDC, managed secrets, centralized observability, and
managed database or messaging services.

## Release Readiness

The application checks, Docker builds, Terraform validation, infrastructure
apply, parallel deployment, health checks, ETL verification, private
integration, event-driven messaging test, end-to-end question retrieval, and
Terraform destroy all passed.

QuizX AWS v2.0.0 is ready for release with this evidence record, the v2
architecture diagram, the demonstration video, and the linked workflow runs.

# QuizX AWS v3.0.0 Test Evidence

Test date: 2026-09-19
Branch: `feature/aws-v3`
AWS region: `eu-west-2`
Release status: Candidate

## Verification Scope

Version 3 adds a custom HTTPS entry point to the distributed QuizX runtime. The
verified request path is:

```text
GoDaddy DNS
  -> API Gateway custom domain and ACM certificate
  -> API Gateway VPC Link
  -> Internal Application Load Balancer
       -> /question/* -> Question App
       -> /submit/*   -> Submit App
```

The existing asynchronous data path remains:

```text
Submit App -> RabbitMQ -> ETL Consumer -> MySQL -> Question App
```

## Local Release-Candidate Verification

Local validation was completed before creating the release-candidate commit.
The test used the repository-root `.env` file, the full Docker Compose `etl`
profile, and images rebuilt from the current source and lockfiles.

Verified:

- all three Node.js services passed their syntax checks;
- production dependency audits reported zero known vulnerabilities after
  compatible lockfile updates;
- the Question App, Submit App, ETL consumer, MySQL, and RabbitMQ images built
  successfully;
- MySQL, RabbitMQ, the Question App, and the Submit App became healthy;
- both user interfaces, health endpoints, readiness endpoints, category
  endpoints, and API documentation endpoints responded successfully;
- prefixed static assets were served successfully for both interfaces;
- the Question App root route returned HTTP `302` with `/question` as its
  redirect location;
- invalid submissions returned HTTP `400`, unknown categories returned HTTP
  `404`, and requested question counts were enforced;
- a unique question submitted through the Submit App was published to
  RabbitMQ, consumed by the ETL service, written to MySQL, and retrieved through
  the Question App;
- RabbitMQ retained a second submission while the ETL consumer was stopped;
- the retained message was consumed and persisted after the ETL consumer
  restarted;
- submitted questions remained retrievable after the MySQL and Question App
  containers were recreated without deleting the database volume;
- the Submit App continued to retrieve the persisted categories after container
  recreation;
- the Submit App returned cached categories while the Question App was stopped,
  and each application remained available while the other application was
  temporarily stopped;
- recent logs for all five containers contained no fatal, unhandled,
  access-denied, or connection-refused errors;
- Terraform formatting and configuration validation passed.

Result: **passed**.

Development verification was completed across the commits listed below. This
record distinguishes the fully deployed architecture test from later CI and
cleanup changes rather than presenting them as one release-commit run.

| Commit | Verification |
|---|---|
| `e420ed6` | Complete infrastructure apply, application deployment, integration checks, and HTTPS routing |
| `4fc2176` | Complete CI pipeline and infrastructure destruction |

## Automated CI Verification

[Successful CI workflow](https://github.com/JacobSidhu/quizx-aws-distributed-system/actions/runs/35456623487)

The workflow completed successfully for commit `4fc2176` and verified:

- dependency installation and JavaScript syntax for the Question App;
- dependency installation and JavaScript syntax for the Submit App;
- dependency installation and JavaScript syntax for the ETL consumer;
- Docker image builds for the Compose services;
- Terraform formatting;
- Terraform backend initialization;
- Terraform configuration validation;
- Terraform planning.

Result: **passed**.

## AWS Infrastructure and Deployment Verification

[Successful apply and deployment workflow](https://github.com/JacobSidhu/quizx-aws-distributed-system/actions/runs/35455202783)

The workflow completed successfully for commit `e420ed6` and verified:

- Terraform initialized against the remote S3 backend;
- the ACM certificate request was created;
- ACM validation records were published through the GoDaddy Domains API;
- certificate validation completed before the remaining infrastructure apply;
- Terraform provisioned the API Gateway, VPC Link, internal ALB, networking,
  security groups, and two EC2 instances;
- the API Gateway application CNAME was published through GoDaddy;
- the Question App, ETL consumer, MySQL, Submit App, and RabbitMQ workloads were
  deployed successfully;
- application health checks passed on both EC2 instances;
- the ETL consumer container check passed;
- temporary GitHub runner SSH access was revoked after deployment.

Result: **passed**.

## Private Service Integration

The deployment workflow tested the Submit App category endpoint from the Submit
EC2 instance. The Submit App successfully contacted the Question App using its
private EC2 address and returned category data.

This verified that:

- `QUESTION_APP_BASE_URL` used the Question App private address;
- the Submit App security group could reach Question App port `4000`;
- cross-instance application traffic did not depend on the public custom domain;
- the Submit App category-cache path had a valid upstream source.

Result: **passed**.

## HTTPS and Path-Routing Verification

The integration job waited for DNS propagation and then tested the custom
domain. It confirmed:

- `https://quizx.lecux.com/question/health` returned successfully;
- `https://quizx.lecux.com/submit/health` returned successfully;
- the root URL returned a redirect to `/question`;
- API Gateway reached both ALB target groups through the VPC Link;
- the ACM-backed custom domain served the routed applications over HTTPS.

Result: **passed**.

## Security Verification

The deployed configuration and workflow verified:

- the ALB was internal;
- VPC Link traffic reached the ALB through security-group references;
- the ALB reached only the configured Question and Submit application ports;
- RabbitMQ AMQP traffic was restricted to the Question App security group;
- MySQL had no public host-port mapping;
- persistent administrator SSH access was controlled by an explicit CIDR;
- GitHub-hosted runners received temporary `/32` SSH rules;
- temporary runner rules were revoked by failure-safe cleanup steps;
- application passwords, AWS credentials, the SSH private key, and GoDaddy
  token were supplied through GitHub Actions secrets;
- Terraform state remained in the encrypted S3 backend and was not committed.

Result: **passed for the tested development deployments**.

## Cleanup Verification

[Successful destroy workflow](https://github.com/JacobSidhu/quizx-aws-distributed-system/actions/runs/35456739926)

The workflow completed successfully for commit `4fc2176` and verified:

- matching GoDaddy application and ACM-validation records were removed;
- Terraform generated the destruction plan successfully;
- the Terraform-managed QuizX infrastructure was destroyed;
- the destroy summary completed successfully;
- the S3 backend remained available for Terraform state history.

Result: **passed**.

## Known Limitations

- The EC2 instances use public subnets for learning visibility.
- Direct application ports use HTTP and are restricted by configured CIDRs;
  normal user traffic uses the API Gateway HTTPS endpoint.
- Deployment uses SSH and long-lived AWS access keys rather than GitHub OIDC.
- MySQL and RabbitMQ are self-managed Docker containers.
- Runtime secrets are not retrieved from AWS Secrets Manager or Parameter Store.
- The public API does not yet include authentication, authorization, rate
  limiting, or AWS WAF.
- Centralized observability and automated vulnerability scanning are not yet
  implemented.

## Release Readiness

The v3 architecture, infrastructure provisioning, parallel application
deployment, private service integration, HTTPS custom-domain routing, CI checks,
and automated cleanup have all passed during development.

Before creating the `v3.0.0` tag, the final release-candidate commit still needs
one consolidated apply run followed by an HTTPS question-submission test that
confirms the ETL consumer persists the submitted question in MySQL. The matching
destroy run should then complete successfully. These final checks ensure the tag
is tied to one exact candidate rather than evidence collected across development
commits.

Current conclusion: **implementation validated; final release-candidate run
required before tagging**.

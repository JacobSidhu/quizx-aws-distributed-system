# QuizX AWS v3.0.0 Test Evidence

Test date: 2026-09-19
Branch: `feature/aws-v3`
AWS region: `eu-west-2`
Release-candidate commit: `7e2d638d2900d7bb9e390fc1209baa7fd029983b`
Release status: **Validated for release; merge and tag pending**

## Verification Scope

Version 3 adds a custom HTTPS entry point to the distributed QuizX runtime:

```text
GoDaddy DNS
  -> API Gateway custom domain and ACM certificate
  -> API Gateway VPC Link
  -> Internal Application Load Balancer
       -> /question/* -> Question App
       -> /submit/*   -> Submit App
```

The asynchronous data path remains:

```text
Submit App -> RabbitMQ -> ETL Consumer -> MySQL -> Question App
```

## Local Release-Candidate Verification

Local validation was completed before the candidate commit. The test used the
repository-root `.env` file, the full Docker Compose `etl` profile, and images
rebuilt from the release-candidate source and lockfiles.

Verified:

- all three Node.js services passed their syntax checks;
- production dependency audits reported zero known vulnerabilities;
- all five service images built successfully;
- MySQL, RabbitMQ, the Question App, and the Submit App became healthy;
- the interfaces, prefixed static assets, health endpoints, readiness endpoints,
  category endpoints, and API documentation endpoints responded successfully;
- the root route returned HTTP `302` with `/question` as its location;
- invalid submissions returned HTTP `400`, unknown categories returned HTTP
  `404`, and requested question counts were enforced;
- a submitted question passed through RabbitMQ and the ETL consumer, was stored
  in MySQL, and was retrieved through the Question App;
- RabbitMQ retained a second submission while the ETL consumer was stopped and
  delivered it after the consumer restarted;
- submitted questions remained available after the MySQL and Question App
  containers were recreated without deleting the database volume;
- the Submit App returned cached categories while the Question App was stopped;
- each application remained available while the other application was stopped;
- recent container logs contained no fatal, unhandled, access-denied, or
  connection-refused errors;
- Terraform formatting and validation passed.

Result: **passed**.

## Automated CI Verification

[Successful CI workflow #68](https://github.com/JacobSidhu/quizx-aws-distributed-system/actions/runs/35469189443)

The workflow ran against the complete release-candidate SHA and verified:

- dependency installation and syntax checks for the Question App;
- dependency installation and syntax checks for the Submit App;
- dependency installation and syntax checks for the ETL consumer;
- Docker Compose image builds;
- Terraform formatting, initialization, validation, and planning.

Result: **passed**.

## AWS Apply and Deployment Verification

[Successful apply and deployment workflow #114](https://github.com/JacobSidhu/quizx-aws-distributed-system/actions/runs/35469548247)

The workflow ran against the complete release-candidate SHA and verified:

- Terraform checks completed against the remote S3 backend;
- the ACM certificate request was created;
- ACM validation records were published through the GoDaddy Domains API;
- ACM certificate validation completed successfully;
- Terraform provisioned the API Gateway, VPC Link, internal ALB, networking,
  security groups, and both EC2 instances;
- the API Gateway application CNAME was published through GoDaddy;
- the Question App, ETL consumer, MySQL, Submit App, and RabbitMQ workloads were
  deployed successfully;
- health checks passed for both application deployments;
- the ETL consumer check passed;
- the Submit App retrieved categories from the Question App over its private EC2
  address;
- API Gateway routed both application health endpoints through the VPC Link and
  internal ALB;
- the root URL redirected to `/question`;
- the deployment summary completed successfully.

Result: **passed**.

## Live HTTPS Verification

Manual browser and API verification was completed while workflow #114 was
deployed.

Verified:

- the ACM certificate for `quizx.lecux.com` was issued and valid;
- the ALB console reported its scheme as `internal`;
- `https://quizx.lecux.com/` redirected to `/question`;
- the Question and Submit interfaces loaded successfully;
- the public Question and Submit health endpoints returned version `3.0.0`;
- the readiness and category routes passed;
- a unique question submitted through the HTTPS Submit route returned HTTP
  `202`;
- the submitted question was retrieved through the HTTPS Question route;
- all four options and the selected correct answer were persisted;
- the ETL consumer showed no processing errors;
- RabbitMQ contained no unexpected queued messages after processing;
- both interfaces displayed adaptively at desktop and mobile widths.

Result: **passed**.

## Security Verification

Verified:

- the ALB was internal;
- the VPC Link, ALB, application, and RabbitMQ paths used security-group
  references;
- MySQL had no public host-port mapping;
- persistent administrator SSH access was restricted to the supplied CIDR;
- the Question App deployment job successfully revoked its temporary runner SSH
  rule;
- the Submit App deployment job successfully revoked its temporary runner SSH
  rule;
- the integration job successfully revoked its temporary runner SSH rule;
- only the intended administrator and inter-service access rules remained after
  deployment;
- application secrets were supplied through GitHub Actions rather than
  committed files;
- Terraform state remained in the encrypted S3 backend.

Result: **passed**.

## Cleanup Verification

[Successful destroy workflow #115](https://github.com/JacobSidhu/quizx-aws-distributed-system/actions/runs/35470976516)

The workflow ran against the complete release-candidate SHA and verified:

- Terraform checks and the destroy plan succeeded;
- the managed GoDaddy application and ACM-validation records were removed;
- Terraform destroy completed successfully;
- both EC2 instances were removed;
- the ALB and target groups were removed;
- API Gateway and VPC Link resources were removed;
- the ACM certificate was removed;
- no unexpected EBS volumes or public IPv4 resources remained;
- the S3 Terraform backend remained available for state history;
- AWS Billing and Cost Explorer were reviewed after cleanup;
- the destroy summary completed successfully.

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

The same candidate commit passed local validation, CI, Terraform planning, AWS
provisioning, parallel application deployment, private service integration,
custom-domain HTTPS routing, an end-to-end submission and persistence test,
security verification, responsive-interface review, and automated cleanup.

Final conclusion: **QuizX AWS v3.0.0 is validated and ready for merge and
tagging. Merge and release remain intentionally pending.**

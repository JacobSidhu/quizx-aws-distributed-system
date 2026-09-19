# Architecture Explanation

QuizX AWS v3.0.0 provides one custom HTTPS entry point for a distributed,
event-driven quiz system running across two Amazon EC2 instances.

## Public Request Path

```text
Client
  -> GoDaddy DNS
  -> API Gateway custom domain with ACM TLS
  -> API Gateway VPC Link
  -> Internal Application Load Balancer
       -> /question and /question/* -> Question App target group
       -> /submit and /submit/*     -> Submit App target group
```

GoDaddy publishes two kinds of CNAME records during deployment: ACM
certificate-validation records and the `quizx.lecux.com` record pointing to the
API Gateway regional domain. API Gateway terminates public TLS and sends its
`$default` route through the VPC Link to the internal ALB.

The ALB listener uses path rules for the two application target groups. Its
default action forwards to the Question App, whose root route redirects users
to `/question`.

## AWS Infrastructure

Terraform provisions:

- one VPC with DNS support and DNS hostnames enabled;
- two public subnets in separate Availability Zones;
- an internet gateway, public route table, and two associations;
- separate Question App, Submit App, VPC Link, and ALB security groups;
- two Ubuntu EC2 instances and one EC2 key pair;
- an internal Application Load Balancer, listener, path rules, target groups,
  and EC2 target attachments;
- an API Gateway HTTP API, default stage, route, VPC Link integration, custom
  domain, and API mapping;
- an ACM certificate and certificate-validation resource.

The VPC Link uses both subnets. The ALB is internal and accepts port `80` only
from the VPC Link security group. It can reach the Question and Submit services
only on ports `4000` and `4200` respectively.

## Distributed Runtime

The Question App EC2 instance runs:

- `quizx-question-app` on host port `4000`;
- `quizx-etl-consumer` with no listening port;
- `quizx-mysql` on the private Docker network only.

The Submit App EC2 instance runs:

- `quizx-submit-app` on host port `4200`;
- `quizx-rabbitmq` with AMQP on host port `5672`.

The Submit App reads categories from the Question App over its private EC2
address and keeps a local category cache for temporary Question App outages.
Submitted questions follow this asynchronous data path:

```text
Submit App -> RabbitMQ -> ETL Consumer -> MySQL -> Question App
```

RabbitMQ retains durable messages when the consumer is temporarily unavailable.
After reconnecting, the ETL consumer processes queued submissions and writes
their categories, questions, and options to MySQL.

## Persistence

MySQL uses the `quizx_mysql_data` Docker volume. RabbitMQ uses
`quizx_rabbitmq_data`, and the Submit App category cache uses
`submit_app_data`. Data survives container recreation while the associated
volumes remain intact. Terraform destruction terminates the EC2 instances and
their Terraform-managed storage, so persistence is scoped to a deployment.

## Security Boundaries

- API Gateway and ACM provide the public HTTPS boundary.
- The VPC Link security group can reach only the internal ALB listener.
- The ALB security group can reach only the application ports.
- RabbitMQ AMQP ingress accepts the Question App security group so the ETL
  consumer can connect across the private EC2 network.
- MySQL is not mapped to an EC2 host port.
- Direct application-port access is controlled by configured CIDRs and exists
  for scoped learning and diagnostics.
- Persistent administrator SSH is controlled by an explicit CIDR input.
- GitHub runner SSH `/32` rules are temporary and revoked after each job.

## CI/CD Lifecycle

The CI workflow checks all three Node.js services, builds the Docker images,
and runs Terraform formatting, initialization, validation, and planning.

The deploy workflow requests the certificate, publishes its validation records,
waits for ACM, applies the remaining infrastructure, publishes the API Gateway
CNAME, deploys both EC2 workloads in parallel, runs health and integration
checks, and revokes temporary runner access. The destroy path removes matching
GoDaddy records before Terraform destroys the AWS application infrastructure.

Terraform state remains in the encrypted S3 backend so apply and destroy runs
share a consistent state history.

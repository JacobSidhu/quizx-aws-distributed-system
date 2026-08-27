# Architecture Explanation

QuizX AWS v2.0.0 runs a distributed, event-driven quiz system across two AWS EC2 instances.

## Infrastructure

Terraform provisions:

- VPC
- Public subnet
- Internet gateway
- Public route table
- Two security groups with restricted inter-service rules
- Two EC2 instances
- EC2 key pair

One instance hosts the Question App workload and the other hosts the Submit App workload. The security groups expose the two application ports, restrict RabbitMQ traffic to the Question App security group, and control SSH using configured CIDRs.

## Runtime

Docker Compose starts five services across the two instances:

- `quizx-question-app` on public port `4000`
- `quizx-submit-app` on public port `4200`
- `quizx-mysql` on internal port `3306`
- `quizx-rabbitmq` for durable question-submission messages
- `quizx-etl-consumer` for consuming messages and persisting them in MySQL

The Submit App publishes to RabbitMQ. The ETL consumer connects to RabbitMQ over the instances' private network, consumes each submission, and writes it to MySQL. The Submit App also reads categories from the Question App over its private address.

## Data Persistence

MySQL stores data in `quizx_mysql_data`, while RabbitMQ uses `quizx_rabbitmq_data`. Data and durable queue state remain available after container recreation as long as the volumes are not deleted.

## CI/CD

The CI workflow checks Node.js syntax, Docker builds, and Terraform validation.

The deploy workflow automates Terraform apply/destroy. On apply, it reads both EC2 public and private addresses, deploys the two workloads in parallel over SSH, checks application and consumer health, verifies private app-to-app integration, and revokes temporary runner SSH rules.

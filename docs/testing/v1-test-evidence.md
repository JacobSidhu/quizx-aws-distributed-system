# QuizX AWS v1.0.0 Test Evidence

Test date: 2026-06-04

## Local Verification

The following checks were run from the repository root:

```bash
npm run check
```

Result:

- `app/question-app/src`: passed JavaScript syntax checks.
- `app/submit-app/src`: passed JavaScript syntax checks.

```bash
docker compose -f infra/docker/docker-compose.yml config
docker compose -f infra/docker/docker-compose.yml build
docker compose -f infra/docker/docker-compose.yml up -d --build
```

Result:

- Docker Compose configuration rendered successfully.
- MySQL, Question App, and Submit App images built successfully.
- MySQL became healthy.
- `quizx-question-app` and `quizx-submit-app` started successfully.

Smoke-tested endpoints:

```bash
curl http://localhost:4000/
curl http://localhost:4200/
curl http://localhost:4000/categories
curl http://localhost:4200/categories
curl "http://localhost:4000/questions/USA?count=1"
curl http://localhost:4200/docs
```

Result:

- Question App UI returned HTTP 200.
- Submit App UI returned HTTP 200.
- Both category endpoints returned category data.
- Question retrieval worked through `/questions/:category`.
- Submit App API docs returned JSON documentation.

## Terraform Verification

The following Terraform checks were run from `infra/terraform`:

```bash
terraform validate
```

Result:

- Terraform configuration is valid.

Local note:

- `terraform fmt -check` failed only because ignored local file `infra/terraform/terraform.tfvars` is not formatted.
- This file is ignored by Git and should not be committed.

## AWS Evidence

The screenshots show:

- Terraform apply completed successfully with 8 resources added.
- GitHub Actions deployed the application to EC2 over SSH after Terraform apply.
- Docker Compose started MySQL, Question App, and Submit App on EC2.
- EC2 instance served the Submit App on public port `4200`.
- Docker Compose ran all three containers on EC2.
- Question App and Submit App were reachable from a browser using EC2 public ports `4000` and `4200`.
- Docker Compose teardown removed the application containers, network, and MySQL volume during cleanup.
- Manual EC2 workflow produced SSH and app URLs for local verification.
- Persistence test confirmed user-created data survived container recreation without deleting the Docker volume.

Existing repository screenshots:

- `docs/screenshots/terraform/successfull-resources-provisioning.png`
- `docs/screenshots/terraform/aws-ec2-ssh-login.png`
- `docs/screenshots/github-actions/ci-workflow-success-summary.png`
- `docs/screenshots/github-actions/terraform-apply-workflow-success.png`
- `docs/screenshots/github-actions/terraform-apply-workflow-log.png`
- `docs/screenshots/github-actions/app-deployed-to-ec2-success.png`
- `docs/screenshots/github-actions/terraform-destroy-plan.png`
- `docs/screenshots/github-actions/terraform-destroy-workflow-success.png`
- `docs/screenshots/manual-ec2/manual-ec2-terraform-outputs.png`
- `docs/screenshots/persistence/submitted-question-ui.png`
- `docs/screenshots/persistence/container-recreate-start.png`
- `docs/screenshots/persistence/container-recreate-success.png`
- `docs/screenshots/persistence/question-after-container-recreate.png`
- `docs/screenshots/apps-running-in-docker-container.png`
- `docs/screenshots/apps-running-locally.png`
- `docs/screenshots/get-all-categories-success.png`
- `docs/screenshots/get-questions-by-category-api-call-success.png`
- `docs/screenshots/get-questions-by-category-with-count-support-api-success.png`

## Persistence Test

A new question was submitted through the Submit App:

- Category: `Science`
- Question: `Persistence test question v1?`
- Correct answer: `Option A`

The containers were recreated without deleting the Docker volume:

```bash
sudo docker compose -f infra/docker/docker-compose.yml down
sudo docker compose -f infra/docker/docker-compose.yml up -d --build
```

After restart, the submitted question was still available from:

```bash
curl "http://13.135.164.184:4000/questions/Science?count=10"
```

Evidence:

- `docs/screenshots/persistence/container-recreate-success.png`
- `docs/screenshots/persistence/question-after-container-recreate.png`

Recommended additional evidence before tagging:

- Short demo video link walking through Terraform, Docker Compose, the two apps, and cleanup.

## Release Readiness Notes

Passed:

- App syntax checks.
- Docker Compose config.
- Docker image builds.
- Local Compose startup.
- Local UI/API smoke tests.
- Terraform validation.
- Terraform user data installs Docker and the Docker Compose plugin on EC2.
- GitHub Actions deploy workflow now deploys the application to EC2 over SSH after Terraform apply.
- Database is private to the Docker network and has no public port mapping.
- Release plan file is untracked and should not be added to GitHub.

Open before final release tag:

- Add a short demo video link, if using video as the primary walkthrough.

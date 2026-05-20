# Contributing

## Principles

- Treat this repository as production infrastructure code.
- Keep modules source-code free. Modules accept artefact references, image URIs, ARNs, and configuration.
- Do not add provider blocks to child modules.
- Use British English in documentation and comments.
- Prefer least-privilege IAM, encryption, finite log retention, DLQs, and required tags.

## Before Opening A PR

Run:

```sh
terraform fmt -check -recursive
./scripts/validate.sh
```

Document any accepted risk in the PR description, including tool gaps such as a LocalStack service that is unavailable in the local edition.

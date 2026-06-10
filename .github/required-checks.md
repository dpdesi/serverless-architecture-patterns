# Required Checks

Configure repository branch protection or rulesets so pull requests cannot merge unless these jobs pass:

- `terraform fmt`
- `terraform validate`
- `terraform test`
- `manifest schema`
- `tflint`
- `conftest`
- `trivy config`
- `localstack smoke`

The rule itself must be created in GitHub by a repository administrator after the repository is published.

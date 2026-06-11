#!/usr/bin/env bash
# Run once per AWS account, with admin credentials for that account, before the
# first deploy. Creates the GitHub OIDC provider (if absent) and the deploy role
# the workflows assume - no long-lived AWS keys are ever stored in GitHub.
#
#   ORG=<github-org> REPO=<repo-name> ./scripts/iac-role.sh
#
# Optional: ROLE_NAME (default atriumIaC), AWS_REGION (default eu-west-2).
set -euo pipefail

: "${ORG:?set ORG to your GitHub org}"
: "${REPO:?set REPO to this repository name}"
ROLE_NAME="${ROLE_NAME:-atriumIaC}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

if ! aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" >/dev/null 2>&1; then
  echo "Creating GitHub OIDC provider..."
  aws iam create-open-id-connect-provider \
    --url "https://token.actions.githubusercontent.com" \
    --client-id-list "sts.amazonaws.com"
fi

TRUST="$(cat <<JSON
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "${OIDC_ARN}" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
      "StringLike": { "token.actions.githubusercontent.com:sub": "repo:${ORG}/${REPO}:*" }
    }
  }]
}
JSON
)"

if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  echo "Updating trust policy on ${ROLE_NAME}..."
  aws iam update-assume-role-policy --role-name "$ROLE_NAME" --policy-document "$TRUST"
else
  echo "Creating role ${ROLE_NAME}..."
  aws iam create-role --role-name "$ROLE_NAME" --assume-role-policy-document "$TRUST"
fi

# Starter permissions. TIGHTEN THIS: scope to the services the subsystem uses
# and the state/artefact buckets. PowerUserAccess + a narrow IAM grant is a
# pragmatic start; replace with a least-privilege policy before production.
aws iam attach-role-policy --role-name "$ROLE_NAME" \
  --policy-arn "arn:aws:iam::aws:policy/PowerUserAccess"
aws iam put-role-policy --role-name "$ROLE_NAME" --policy-name "iac-iam" \
  --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["iam:CreateRole","iam:DeleteRole","iam:GetRole","iam:PassRole","iam:AttachRolePolicy","iam:DetachRolePolicy","iam:PutRolePolicy","iam:DeleteRolePolicy","iam:GetRolePolicy","iam:ListRolePolicies","iam:ListAttachedRolePolicies","iam:TagRole","iam:UntagRole"],"Resource":"*"}]}'

echo "Deploy role ready: arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo "Set the GitHub Environment variable AWS_ACCOUNT_ID=${ACCOUNT_ID} (and IAC_ROLE_NAME=${ROLE_NAME} if not default)."

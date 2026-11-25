#!/usr/bin/env bash
# Budget equipe AA (G0) - 150 CHF ~ 185 USD, alerte a 80 %.
# AWS::Budgets::Budget indisponible en CloudFormation (eu-north-1) : script idempotent.
# Usage : ./scripts/budget.sh <email-alerte>
set -euo pipefail

EMAIL="${1:?Usage : $0 <email-alerte>}"
NAME="budget-leman-AA"
LIMIT="185"
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
TMP=$(mktemp -d)

cat > "$TMP/budget.json" <<EOF
{
  "BudgetName": "$NAME",
  "BudgetLimit": { "Amount": "$LIMIT", "Unit": "USD" },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST",
  "CostFilters": { "TagKeyValue": ["user:Equipe\$Assaga"] }
}
EOF

cat > "$TMP/notifications.json" <<EOF
[
  { "Notification": { "NotificationType": "ACTUAL", "ComparisonOperator": "GREATER_THAN",
                      "Threshold": 80, "ThresholdType": "PERCENTAGE" },
    "Subscribers": [ { "SubscriptionType": "EMAIL", "Address": "$EMAIL" } ] },
  { "Notification": { "NotificationType": "FORECASTED", "ComparisonOperator": "GREATER_THAN",
                      "Threshold": 100, "ThresholdType": "PERCENTAGE" },
    "Subscribers": [ { "SubscriptionType": "EMAIL", "Address": "$EMAIL" } ] }
]
EOF

if aws budgets describe-budget --account-id "$ACCOUNT" --budget-name "$NAME" >/dev/null 2>&1; then
  echo "Budget existant : mise a jour de la limite et des filtres"
  aws budgets update-budget --account-id "$ACCOUNT" --new-budget "file://$TMP/budget.json"
else
  echo "Creation du budget $NAME"
  aws budgets create-budget --account-id "$ACCOUNT" \
    --budget "file://$TMP/budget.json" \
    --notifications-with-subscribers "file://$TMP/notifications.json" \
    --resource-tags Key=Projet,Value=SatomCloudNetwork Key=Equipe,Value=Assaga \
                    Key=Environnement,Value=shared Key=Module,Value=G0-budget
fi

aws budgets describe-budget --account-id "$ACCOUNT" --budget-name "$NAME" \
  --query "Budget.{Nom:BudgetName,Limite:BudgetLimit.Amount,Filtre:CostFilters}" --output json
aws budgets describe-notifications-for-budget --account-id "$ACCOUNT" --budget-name "$NAME" \
  --query "Notifications[].[NotificationType,Threshold]" --output table
rm -rf "$TMP"
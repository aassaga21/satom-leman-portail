#!/usr/bin/env bash
# Deploiement des stacks d'un environnement par change set (pipeline, etape 4 et 6).
# Refuse toute suppression ou tout remplacement de ressource, sauf ALLOW_DESTRUCTIVE=true.
# Usage : ./scripts/deploy.sh <dev|prod>
# Variable requise : CFN_EXEC_ROLE_ARN
set -euo pipefail

ENV="${1:?Usage : $0 <dev|prod>}"
[[ "$ENV" == "dev" || "$ENV" == "prod" ]] || { echo "Environnement invalide : $ENV"; exit 2; }
: "${CFN_EXEC_ROLE_ARN:?Variable CFN_EXEC_ROLE_ARN manquante}"
REGION="${AWS_REGION:-eu-north-1}"
SUFFIX="AA"
PARAMS_FILE="parameters/${ENV}.json"
ALLOW_DESTRUCTIVE="${ALLOW_DESTRUCTIVE:-false}"
CS_NAME="cs-$(date +%Y%m%d%H%M%S)"

# Ordre de deploiement (nom logique:template)
STACKS=(
  "base:templates/01-base.yaml"
  "network:templates/10-network.yaml"
)

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

stack_status() {
  aws cloudformation describe-stacks --region "$REGION" --stack-name "$1" \
    --query "Stacks[0].StackStatus" --output text 2>/dev/null || echo "ABSENTE"
}

afficher_echecs() {
  echo "Evenements en echec :"
  aws cloudformation describe-stack-events --region "$REGION" --stack-name "$1" \
    --query "StackEvents[?contains(ResourceStatus,'FAILED')].[LogicalResourceId,ResourceStatusReason]" \
    --output table || true
}

for entry in "${STACKS[@]}"; do
  NAME="${entry%%:*}"
  TEMPLATE="${entry#*:}"
  STACK="stack-leman-${ENV}-${NAME}-${SUFFIX}"
  echo "=================================================="
  echo " Stack : $STACK ($TEMPLATE)"
  echo "=================================================="

  # 1. Parametres : uniquement ceux declares par le template
  aws cloudformation validate-template --region "$REGION" --template-body "file://$TEMPLATE" \
    --query "Parameters[].ParameterKey" --output json > "$TMP/keys.json"
  jq --slurpfile keys "$TMP/keys.json" \
    'to_entries
     | map(select(.key as $k | $keys[0] | index($k)))
     | map({ParameterKey: .key, ParameterValue: (.value | tostring)})' \
    "$PARAMS_FILE" > "$TMP/params.json"
  echo "Parametres transmis : $(jq -c 'map(.ParameterKey)' "$TMP/params.json")"

  # 2. Type de change set selon l'etat de la stack
  STATUS=$(stack_status "$STACK")
  case "$STATUS" in
    ABSENTE)
      TYPE=CREATE ;;
    ROLLBACK_COMPLETE|REVIEW_IN_PROGRESS)
      echo "Stack en $STATUS : suppression avant recreation"
      aws cloudformation delete-stack --region "$REGION" --stack-name "$STACK"
      aws cloudformation wait stack-delete-complete --region "$REGION" --stack-name "$STACK"
      TYPE=CREATE ;;
    *_IN_PROGRESS)
      echo "Stack occupee ($STATUS) : abandon"; exit 1 ;;
    *)
      TYPE=UPDATE ;;
  esac
  echo "Etat actuel : $STATUS -> change set de type $TYPE"

  # 3. Creation du change set
  aws cloudformation create-change-set --region "$REGION" \
    --stack-name "$STACK" --change-set-name "$CS_NAME" --change-set-type "$TYPE" \
    --template-body "file://$TEMPLATE" --parameters "file://$TMP/params.json" \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    --role-arn "$CFN_EXEC_ROLE_ARN" \
    --tags Key=Projet,Value=SatomCloudNetwork Key=Equipe,Value=Assaga Key=Environnement,Value="$ENV" \
    > /dev/null

  if ! aws cloudformation wait change-set-create-complete --region "$REGION" \
       --stack-name "$STACK" --change-set-name "$CS_NAME" 2>/dev/null; then
    REASON=$(aws cloudformation describe-change-set --region "$REGION" --stack-name "$STACK" \
      --change-set-name "$CS_NAME" --query StatusReason --output text)
    aws cloudformation delete-change-set --region "$REGION" --stack-name "$STACK" --change-set-name "$CS_NAME"
    if [[ "$REASON" == *"didn't contain changes"* || "$REASON" == *"No updates are to be performed"* ]]; then
      echo "Aucun changement : stack deja a jour"
      continue
    fi
    echo "ERREUR lors de la creation du change set : $REASON"
    exit 1
  fi

  # 4. Revue du change set
  aws cloudformation describe-change-set --region "$REGION" --stack-name "$STACK" \
    --change-set-name "$CS_NAME" --query "Changes[].ResourceChange" --output json > "$TMP/changes.json"
  echo "Changements prevus :"
  jq -r '.[] | "  \(.Action)  \(.LogicalResourceId)  (\(.ResourceType))  remplacement=\(.Replacement // "-")"' "$TMP/changes.json"

  DESTRUCTIFS=$(jq '[.[] | select(.Action == "Remove" or .Replacement == "True" or .Replacement == "Conditional")] | length' "$TMP/changes.json")
  if (( DESTRUCTIFS > 0 )) && [[ "$ALLOW_DESTRUCTIVE" != "true" ]]; then
    echo "REFUS : $DESTRUCTIFS suppression(s) ou remplacement(s) non confirme(s)."
    echo "Relancer avec ALLOW_DESTRUCTIVE=true apres validation."
    aws cloudformation delete-change-set --region "$REGION" --stack-name "$STACK" --change-set-name "$CS_NAME"
    exit 1
  fi

  # 5. Execution
  aws cloudformation execute-change-set --region "$REGION" --stack-name "$STACK" --change-set-name "$CS_NAME"
  if [[ "$TYPE" == "CREATE" ]]; then
    aws cloudformation wait stack-create-complete --region "$REGION" --stack-name "$STACK" \
      || { afficher_echecs "$STACK"; exit 1; }
  else
    aws cloudformation wait stack-update-complete --region "$REGION" --stack-name "$STACK" \
      || { afficher_echecs "$STACK"; exit 1; }
  fi
  echo "OK : $STACK -> $(stack_status "$STACK")"
done

echo "Deploiement $ENV termine."
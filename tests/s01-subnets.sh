#!/usr/bin/env bash
# Sprint 1 - Preuve : VPC, sous-reseaux, routage prive, Flow Logs chiffres, KMS.
# Usage : ./tests/s01-subnets.sh <dev|prod>
set -uo pipefail

ENV="${1:?Usage : $0 <dev|prod>}"
REGION="${AWS_REGION:-eu-north-1}"
SUFFIX="AA"
PARAMS="parameters/${ENV}.json"
ECHECS=0

check() {  # check "<libelle>" "<attendu>" "<obtenu>"
  if [[ "$2" == "$3" ]]; then
    printf "PASS  %-55s attendu=%s obtenu=%s\n" "$1" "$2" "$3"
  else
    printf "FAIL  %-55s attendu=%s obtenu=%s\n" "$1" "$2" "$3"
    ECHECS=$((ECHECS + 1))
  fi
}

echo "=== Sprint 1 - preuve $ENV - $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="

# 1. VPC
read -r VPC_ID VPC_CIDR < <(aws ec2 describe-vpcs --region "$REGION" \
  --filters "Name=tag:Name,Values=vpc-${ENV}-leman-${SUFFIX}" \
  --query "Vpcs[0].[VpcId,CidrBlock]" --output text)
echo "VPC : $VPC_ID ($VPC_CIDR)"
check "CIDR du VPC" "$(jq -r .VpcCidr "$PARAMS")" "$VPC_CIDR"

# 2 a 4. Sous-reseaux
SUBNETS=$(aws ec2 describe-subnets --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "Subnets[].{id:SubnetId,az:AvailabilityZone,tier:Tags[?Key=='Tier']|[0].Value,ipauto:MapPublicIpOnLaunch,cidr:CidrBlock}" \
  --output json)
echo "$SUBNETS" | jq -r '.[] | "  \(.tier)\t\(.az)\t\(.cidr)\t\(.id)\tip_publique_auto=\(.ipauto)"'
check "Nombre de sous-reseaux"                "4" "$(echo "$SUBNETS" | jq 'length')"
check "Sous-reseaux publics"                  "2" "$(echo "$SUBNETS" | jq '[.[] | select(.tier=="public")]  | length')"
check "Sous-reseaux prives"                   "2" "$(echo "$SUBNETS" | jq '[.[] | select(.tier=="private")] | length')"
check "Zones de disponibilite distinctes"     "2" "$(echo "$SUBNETS" | jq '[.[].az] | unique | length')"
check "Sous-reseaux avec IP publique auto"    "0" "$(echo "$SUBNETS" | jq '[.[] | select(.ipauto==true)] | length')"

# 5. Aucune route privee vers un IGW
PRIVES=$(echo "$SUBNETS" | jq -r '[.[] | select(.tier=="private") | .id] | join(",")')
ROUTES_IGW=$(aws ec2 describe-route-tables --region "$REGION" \
  --filters "Name=association.subnet-id,Values=$PRIVES" \
  --query "length(RouteTables[].Routes[?starts_with(GatewayId || '', 'igw-')][])" --output text)
check "Routes privees vers un IGW"            "0" "$ROUTES_IGW"

# 6. Flow Logs
read -r FL_STATUS FL_GROUP FL_TRAFIC < <(aws ec2 describe-flow-logs --region "$REGION" \
  --filter "Name=resource-id,Values=$VPC_ID" \
  --query "FlowLogs[0].[FlowLogStatus,LogGroupName,TrafficType]" --output text)
check "Flow Logs actifs"                      "ACTIVE" "$FL_STATUS"
check "Flow Logs - type de trafic"            "ALL"    "$FL_TRAFIC"

# 7. Log group chiffre et retenu
read -r LG_KMS LG_RET < <(aws logs describe-log-groups --region "$REGION" \
  --log-group-name-prefix "$FL_GROUP" \
  --query "logGroups[0].[kmsKeyId,retentionInDays]" --output text)
check "Log group chiffre par KMS"             "oui" "$([[ "$LG_KMS" == arn:aws:kms:* ]] && echo oui || echo non)"
check "Retention du log group (jours)"        "365" "$LG_RET"

# 8. Rotation KMS
KEY_ID=$(aws kms describe-key --region "$REGION" --key-id "alias/kms-leman-${ENV}-${SUFFIX}" \
  --query KeyMetadata.KeyId --output text)
check "Rotation de la cle KMS"                "True" "$(aws kms get-key-rotation-status --region "$REGION" \
  --key-id "$KEY_ID" --query KeyRotationEnabled --output text)"

echo "=== Resultat : $ECHECS echec(s) ==="
exit "$ECHECS"
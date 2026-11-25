# ADR-002 : PowerUserAccess pour le rôle d'exécution CloudFormation

- **Statut :** accepté
- **Date :** 2026-11-25
- **Propriétaire :** Alexandra Assaga
- **Date de revue :** 2026-12-09 (fin du sprint 12)

## Contexte
Le rôle `role-cfn-exec-leman-AA` crée toutes les ressources des 13 sprints : réseau, ALB, Route 53, CloudFront, KMS, Network Firewall, supervision, etc. Lister finement chaque action dès G0 bloquerait les sprints à chaque nouveau service.

## Décision
- La politique gérée `PowerUserAccess` est attachée : elle donne tous les services **sauf IAM et Organizations**.
- IAM est ajouté de façon restreinte :
  - les rôles et instance profiles ne peuvent être créés que sous le chemin `/leman-aa/` ;
  - seules `AmazonSSMManagedInstanceCore` et `CloudWatchAgentServerPolicy` sont attachables ;
  - `iam:CreateServiceLinkedRole` est limité à `aws-service-role/*`.
- Les rôles du bootstrap sont hors de `/leman-aa/`. Le rôle d'exécution ne peut donc pas modifier ses propres droits.
- Le rôle n'est assumable que par `cloudformation.amazonaws.com` depuis ce compte (`aws:SourceAccount`).

## Conséquences
- Il n'y a pas d'élévation de privilèges possible via IAM. checkov ne relève aucun échec (18 passed).
- Le périmètre hors IAM reste large. checkov n'analyse pas le contenu de `PowerUserAccess`.

## Risque accepté
Un template malveillant mergé pourrait créer des ressources coûteuses ou exposées. Ce risque est compensé par la PR obligatoire, cfn-guard et checkov dans la pipeline, l'approbation avant prod, et le budget avec alertes.

## Action
Au sprint 12, extraire les actions réellement utilisées avec IAM Access Analyzer (génération de politique) et remplacer `PowerUserAccess`.
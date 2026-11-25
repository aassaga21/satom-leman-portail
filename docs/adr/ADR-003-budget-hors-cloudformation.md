# ADR-003 : budget géré par script et non par CloudFormation

- **Statut :** accepté
- **Date :** 2026-11-25
- **Propriétaire :** Alexandra Assaga
- **Date de revue :** 2026-12-09

## Contexte
Le sujet impose un budget de 150 CHF par équipe, avec une alerte à 80 %. Le type `AWS::Budgets::Budget` n'est pas disponible en CloudFormation dans la région eu-north-1 (constaté en v1). Le compte AWS est partagé avec la classe.

## Décision
- Le budget est créé par `scripts/budget.sh` : un script versionné, relu en PR et idempotent (création ou mise à jour).
- `budget-leman-AA` : 185 USD par mois (environ 150 CHF), filtré sur le tag `Equipe=Assaga`.
- Deux alertes par e-mail : coût réel supérieur à 80 %, et prévision supérieure à 100 %.
- L'adresse e-mail est passée en argument au lancement du script : elle n'est jamais écrite dans le dépôt.

## Conséquences
- C'est une exception au principe « tout en CloudFormation ». Le budget reste toutefois versionné et reproductible.
- Le filtre par tag ne comptabilise rien si `Equipe` n'est pas activé comme tag de répartition des coûts.

## Risque accepté
Si le tag de répartition n'est pas activé, l'alerte ne se déclenchera jamais. Ce risque est compensé par la suppression systématique des ressources facturées à l'heure après chaque session.

## Action
Demander au formateur d'activer le tag `Equipe` dans le compte de facturation.
# ADR-001 : relecture des pull requests sans second membre

- **Statut :** accepté (temporaire)
- **Date :** 2026-11-25
- **Propriétaire :** Alexandra Assaga
- **Date de revue :** 2026-12-09

## Contexte
Le sujet impose que chaque module passe par une pull request relue par un autre membre de l'équipe. L'équipe AA ne compte qu'une personne, et GitHub n'autorise pas l'auteur d'une PR à l'approuver lui-même.

## Décision
- La protection de `main` impose une PR pour toute modification (aucun commit direct, y compris pour les admins).
- Le nombre d'approbations requises est fixé à **0** tant qu'aucun relecteur n'est désigné.
- Chaque PR décrit ses contrôles (cfn-lint, checkov, tests) dans sa description.
- Les status checks de la pipeline deviendront obligatoires dès leur première exécution.

## Conséquences
- La traçabilité est conservée : chaque changement est une PR, avec un historique linéaire.
- Le principe des « quatre yeux » n'est pas respecté.

## Risque accepté
Un changement erroné peut être mergé sans regard extérieur. Ce risque est compensé par les contrôles automatiques et par l'approbation manuelle obligatoire avant tout déploiement en prod.

## Action
Demander au formateur un relecteur, puis passer `required_approving_review_count` à 1.
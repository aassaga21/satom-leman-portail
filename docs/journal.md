# Journal de projet

| Sprint | Date | Livré | Preuve | DORA (fréquence / délai / échec / MTTR) |
|---|---|---|---|---|
| G0 | 2026-11-25 | Nouveau dépôt, protection de `main`, environnements dev/prod, bootstrap OIDC, budget, ADR 001 à 003 | Push direct refusé (GH006) ; workflow OIDC : assume-role OK et Deny bootstrap OK ; budget créé avec alertes 80 % et 100 % | 2 déploiements (bootstrap) / délai PR→déploiement < 5 min / 1 échec sur 2 (50 %, sujet OIDC) / MTTR 18 min |
| S1 | 2026-11-25 | Clé KMS par environnement, VPC dev (10.1.0.0/16) et prod (10.0.0.0/16), 4 sous-réseaux sur 2 zones, tables de routage sans route sortante, Flow Logs chiffrés (365 j), règles cfn-guard, script de déploiement par change set, pipeline complète, contrôles obligatoires sur `main` | cfn-guard : templates PASS, template non conforme FAIL ×5 ; pipeline run #6 : `s01-subnets.sh` 12/12 PASS en dev et en prod (artefacts `preuve-s01-dev` et `preuve-s01-prod`) | 3 déploiements pipeline (runs #2, #4, #6) / délai merge→prod ≈ 8 min (approbation incluse) / 0 échec sur 3 (0 %) / MTTR : sans objet |

## G0 - Notes
- Échec : refus OIDC dû au format de sujet immutable (`repo:owner@id/repo@id:environment:dev`). Corrigé par la PR #3.
- PR mergées : #1 à #5.

## S1 - Notes
- Les Flow Logs sont activés dès le sprint 1 : checkov exige des Flow Logs sur tout VPC, et le sujet exige 100 % de chiffrement. La clé KMS est donc créée avant le réseau.
- Une table de routage privée par zone, pour préparer une NAT par zone au sprint 2.
- Le rôle de déploiement a reçu 7 actions de lecture (PR #7) pour que la pipeline exécute elle-même les tests.
- Les jobs « 1 - Qualite » et « 2 - Securite » sont devenus obligatoires sur `main` après leur première exécution.
- PR mergées : #6 à #8.
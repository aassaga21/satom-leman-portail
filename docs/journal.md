# Journal de projet

| Sprint | Date | Livré | Preuve | DORA (fréquence / délai / échec / MTTR) |
|---|---|---|---|---|
| G0 | 2026-11-25 | Nouveau dépôt, protection de `main`, environnements dev/prod, bootstrap OIDC, budget, ADR 001 à 003 | Push direct refusé (GH006) ; workflow OIDC : assume-role OK et Deny bootstrap OK ; budget créé avec alertes 80 % et 100 % | 2 déploiements (bootstrap) / délai PR→déploiement < 5 min / 1 échec sur 2 (50 %, sujet OIDC) / MTTR 18 min |

## G0 - Notes
- Échec : refus OIDC dû au format de sujet immutable (`repo:owner@id/repo@id:environment:dev`). Corrigé par la PR #3.
- PR mergées : #1 à #5.
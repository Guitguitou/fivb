# Ferry Watcher — Beach Pro Tour Modena 2026

Surveille automatiquement la position de Pascal Ferry / Vincent Ferry (MON)
sur les listes Reserve / Qualification / Main Draw du tournoi, et t'envoie un
WhatsApp (via CallMeBot) dès que ça bouge.

## Mise en place (5 min)

### 1. Active CallMeBot (à faire en premier, ça peut prendre du temps)

1. Va sur https://www.callmebot.com/whatsapp/ et récupère le numéro de bot
   actuel (il change de temps en temps, ne pas réutiliser un vieux numéro
   trouvé ailleurs).
2. Ajoute ce numéro à tes contacts.
3. Envoie-lui sur WhatsApp : `I allow callmebot to send me messages`
4. Il te répond avec ta clé API : `API Activated ... Your APIKEY is XXXXX`.
   Si tu ne reçois rien en 2 min, réessaie après 24h (le bot est parfois plein).

### 2. Crée un repo GitHub

Public ou privé, peu importe — pas de donnée sensible dans le code (les
secrets restent dans les GitHub Secrets, jamais dans les fichiers).

Pousse ces 5 fichiers tels quels :
- `check_position.rb`
- `Gemfile`
- `state.json`
- `.github/workflows/watch.yml`
- `README.md`

### 3. Ajoute les secrets du repo

Dans `Settings > Secrets and variables > Actions`, ajoute :
- `CALLMEBOT_PHONE` : ton numéro complet avec indicatif pays, sans le `+`
  (ex : `33612345678`)
- `CALLMEBOT_APIKEY` : la clé reçue à l'étape 1

### 4. Teste manuellement

Onglet `Actions` du repo > `Suivi Ferry/Ferry - Beach Pro Tour Modena` >
`Run workflow`. Regarde les logs : tu dois voir la position actuelle
détectée (pas de notification à ce premier lancement, c'est normal — il
enregistre juste l'état de départ).

Relance une deuxième fois `Run workflow` juste après : ça doit dire
"Aucun changement." Si tu veux forcer un test de notification, modifie
temporairement `state.json` en mettant `{"draw": "reserve", "position": "99"}`
avant de relancer.

## Fonctionnement

- Le script tourne toutes les 15 minutes (cron GitHub Actions).
- Il regarde Reserve, puis Qualification, puis Main Draw, et s'arrête au
  premier tableau où "Pascal Ferry" ou "Vincent Ferry" apparaît.
- Si la position ou le tableau a changé depuis la dernière vérification,
  il envoie un WhatsApp et met à jour `state.json` (committé automatiquement
  dans le repo, donc l'historique des changements reste visible dans les
  commits).
- Si l'équipe disparaît des trois tableaux (retrait, etc.), tu reçois aussi
  une alerte.

## Limites connues

- CallMeBot est un service tiers non-officiel : gratuit et simple, mais pas
  garanti à 100% dans la durée (usage personnel uniquement, rate-limité).
- Le scraping dépend de la structure HTML actuelle du site
  volleyballworld.com. Si le site change de mise en page, le script peut
  ne plus rien trouver — dans ce cas les logs Actions te le montreront
  (aucune position détectée sur aucun tableau).
- Le cron GitHub Actions n'est pas garanti à la minute près (délai possible
  en période de forte charge), mais 15 min de marge est largement suffisant
  ici.

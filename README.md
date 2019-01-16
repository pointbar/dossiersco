# DossierSCO

[![CircleCI](https://circleci.com/gh/betagouv/dossiersco.svg?style=svg)](https://circleci.com/gh/betagouv/dossiersco)

Inscrire ses enfants au collège sans se déplacer, sans redonner d'information déjà connues et sans flux papier.

Dans le répertoire dossiersco, lancer :

    docker-compose up

L'accès à l'application se fait ensuite par <http://0.0.0.0:9393/>.

## Outils

- Tous les identifiants et mots de passe sont stockés dans Keybase
- Les mails transactionnels sont envoyés via [Mailjet](https://mailjet.com)
- On attrape toutes les erreurs sur [Sentry](https://sentry.io/betagouv-pe/rails/)
- Sur les environnements de développement et staging les emails sortants sont envoyés
    avec Letter Opener Web. On peut les consulter à l'url '/letter_opener'

## Vie de l'équipe

- Vous pouvez nous retrouver chaque lundi et jeudi au [110bis Lab](http://www.education.gouv.fr/110bislab/pid37871/bienvenue-au-110-bis-le-lab-d-innovation-de-l-education-nationale.html) rue de Grenelle à Paris
- Retrouvez notre [agenda public](https://calendar.google.com/calendar/embed?src=contact%40dossiersco.beta.gouv.fr&ctz=Europe%2FParis)
- [Journal de l'équipe](https://github.com/betagouv/dossiersco/blob/master/doc/journal.md)

# Security Foundations — lab Docker isolé

Cette maquette locale met en place une application DVWA volontairement
vulnérable, sa base MariaDB, un poste Kali et une passerelle combinant routage,
IDS Suricata et pare-feu. Elle est exclusivement destinée à un exercice
autorisé sur les services inclus dans ce dépôt.

## Architecture

```text
Kali (172.28.10.10)
  └─ attack ── Gateway / Suricata / firewall
                   └─ app ── DVWA (172.28.20.20)
                                  └─ data ── MariaDB (172.28.30.30)
```

Les trois réseaux Docker n'exposent aucun port vers l'hôte : l'accès à DVWA
passe donc obligatoirement par la passerelle. Kali et la passerelle suppriment
également leur route par défaut au démarrage, afin de ne joindre que les sous-
réseaux du lab. N'ajoutez pas de ports publiés. Le flag Docker `internal` n'est
pas utilisé sur `attack` et `app`, car il empêche le routage inter-réseaux
nécessaire à la passerelle sous Docker Desktop.
MariaDB est seulement raccordée au réseau `data`; Kali et la passerelle ne
peuvent pas la joindre directement.

## Préparation

```sh
cp .env.example .env
docker compose build --pull
docker compose up -d
docker compose ps
```

Les valeurs de `.env` sont exclusivement destinées au lab. Le fichier est
ignoré par Git ; partagez-le uniquement dans le canal privé du groupe, et ne
réutilisez jamais ces identifiants.

Les images externes sont épinglées par digest afin que tous les membres
obtiennent la même image. Elles ont été vérifiées pour `linux/arm64`.

## Utilisation de Kali

Le conteneur démarre en root uniquement pour définir sa route vers la
passerelle. Ouvrez ensuite un terminal non privilégié :

```sh
docker compose exec --user kali kali bash
```

Depuis ce terminal, l'application est disponible à `http://172.28.20.20/`.
La procédure de configuration initiale propre à DVWA s'effectue uniquement
depuis ce lab. Ne publiez pas le service vers le réseau local.

## Observer les alertes

```sh
docker compose logs -f gateway
tail -f evidence/suricata/fast.log
```

La règle `gateway/rules/local.rules` est un exemple pédagogique. Elle détecte
un jeton de requête suspect destiné à DVWA. Le groupe doit l'adapter au scénario
autorisé, la tester et expliquer son choix dans le rapport.

## Démonstration de protection

Après avoir établi et consigné une alerte, appliquer l'isolation de l'endpoint
Kali de démonstration :

```sh
docker compose exec gateway /opt/lab/firewall/block-kali.sh
```

Pour annuler cette mesure :

```sh
docker compose exec gateway /opt/lab/firewall/unblock-kali.sh
```

Le filtrage de base est restauré à chaque recréation de la passerelle.

## Cycle de vie

```sh
# Arrêter le lab sans supprimer la base
docker compose down

# Repartir à zéro : supprime aussi les données MariaDB du lab
docker compose down -v
```

Ne lancez jamais ce projet avec `network_mode: host`, `privileged: true`, un
montage de `/var/run/docker.sock`, ou des ports publiés sans nécessité
documentée.

## Qualité et vérifications avant commit

Le dépôt utilise [pre-commit](https://pre-commit.com/) pour vérifier les
fichiers YAML, les erreurs Git courantes, les clés privées, les secrets
(Gitleaks via son image Docker), les Dockerfiles (Hadolint) et la configuration
Compose.

Après le clonage :

```sh
pre-commit install
pre-commit run --all-files
```

`pre-commit` peut aussi être lancé sans installation globale avec uv :

```sh
uv tool run pre-commit install
uv tool run pre-commit run --all-files
```

La GitHub Action `Validation` rejoue ces contrôles à chaque push sur `main` et
à chaque pull request. Elle construit uniquement les images locales Kali et
gateway : elle ne démarre pas le lab et ne lance pas DVWA, épinglée pour ARM64.

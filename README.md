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

Les flux de démonstration passent obligatoirement par la passerelle. DVWA
publie toutefois son interface visuelle uniquement sur `127.0.0.1:8080` : elle
est disponible sur l'hôte à `http://localhost:8080`, mais cet accès local ne
traverse pas Suricata et ne doit pas être utilisé pour les attaques de la
démonstration. Kali et la passerelle suppriment également leur route par défaut
au démarrage, afin de ne joindre que les sous-réseaux du lab. Le flag Docker
`internal` n'est pas utilisé sur `attack` et `app`, car il empêche le routage
inter-réseaux nécessaire à la passerelle sous Docker Desktop.
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

Les images externes sont épinglées par digest d'index multi-architecture afin
que tous les membres obtiennent la même version, avec le manifeste adapté à
leur processeur. Elles ont été vérifiées pour `linux/arm64` et `linux/amd64`.
Sous Windows, Docker Desktop doit être configuré pour les conteneurs Linux.

## Utilisation de Kali

Le conteneur démarre en root uniquement pour définir sa route vers la
passerelle. Ouvrez ensuite un terminal non privilégié :

```sh
docker compose exec --user kali kali bash
```

Depuis ce terminal, l'application est disponible à `http://172.28.20.20/`.
L'interface visuelle locale est à `http://localhost:8080`. Elle sert à observer
DVWA ou à expliquer son fonctionnement ; les scénarios et leur détection sont
toujours exécutés depuis Kali.

L'image Kali contient aussi `sqlmap` pour l'analyse de l'injection SQL de cette
maquette, `hydra` pour comparer une automatisation d'authentification, et `tldr`
(fourni par le paquet `tealdeer`) pour consulter les résumés de commandes.
`sqlmap` et Hydra doivent rester limités à DVWA, avec les identifiants de test
du laboratoire ; ne leur fournissez jamais une cible extérieure au projet.
Le cache `tldr` est téléchargé pendant la construction de l'image car Kali n'a
volontairement pas de route Internet une fois le laboratoire démarré.

```sh
docker compose exec --user kali kali tldr sqlmap
docker compose exec --user kali kali sqlmap --help
docker compose exec --user kali kali hydra --help
```

## Scénarios reproductibles

Les scripts dans `scenarios/` s'exécutent exclusivement dans le conteneur Kali,
enregistrent leurs sorties sous `evidence/` et utilisent une liste de mots de
passe volontairement courte. Initialiser DVWA efface et recrée les données de
ce laboratoire : n'exécutez cette commande que pour repartir d'un état propre.

```sh
make reset   # initialise DVWA et sélectionne le niveau Low
make recon   # scan limité de DVWA depuis Kali
make brute   # rejeu de cinq tentatives d'authentification maximum
make sqli    # rejeu d'une requête SQLi contrôlée
```

Dans un second terminal, observez les alertes avant de passer à la protection :

```sh
make alerts
make block     # isole Kali après validation manuelle de l'alerte
make brute     # le rejeu doit maintenant échouer
make unblock   # revient à la politique de base
```

Le scénario SQLi emploie la charge `1' OR '1'='1` uniquement contre DVWA au
niveau Low. Il démontre une lecture de plusieurs lignes factices ; il ne tente
ni écriture, ni exfiltration hors de la maquette.

## Observer les alertes

```sh
docker compose logs -f gateway
tail -f evidence/suricata/fast.log
```

Les règles `gateway/rules/local.rules` détectent les requêtes répétées vers le
formulaire Brute Force et le motif SQLi du scénario. Elles sont volontairement
spécifiques à cette maquette : le groupe doit expliquer leurs limites et les
évaluer face aux faux positifs et faux négatifs dans le rapport.

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
gateway : elle ne démarre pas le lab.

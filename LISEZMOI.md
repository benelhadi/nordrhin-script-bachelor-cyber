# Projet NordRhin Distribution : mise en place de l'environnement

Bachelor 3 · Administration Systèmes Linux/Windows · Projet final individuel

Ce dépôt met tes deux machines virtuelles dans l'état de départ du projet. Le sujet et le guide par question te sont remis à part.

> **À lire avant de lancer quoi que ce soit.** Ces scripts modifient profondément la machine : comptes, droits, services, domaine. Lance-les **uniquement** sur des machines virtuelles créées pour le projet. Ils n'installent aucun programme malveillant : tout ce qu'ils posent est une mauvaise configuration ou un fichier texte. Lis-les avant de les exécuter, c'est la première chose qu'un administrateur fait.

## Ce qu'il te faut

| Machine | Système | RAM | Disque |
|---|---|---|---|
| `srv-files01` | Ubuntu Server 24.04 LTS | 2 Go | 20 Go |
| `DC01` | Windows Server 2022 Standard, évaluation, **avec Expérience de bureau** | 4 Go | 40 Go |

- Hyperviseur : VirtualBox ou VMware, au choix.
- Réseau : chaque machine a besoin d'Internet (mises à jour) et d'un réseau commun avec l'autre. Deux cartes par machine (une NAT, une réseau privé) ou un seul réseau NAT partagé conviennent.
- Ubuntu : coche « Install OpenSSH server » pendant l'installation.
- Windows Server : donne-lui une **adresse IP fixe** avant de créer le domaine.

## Ton identifiant

Les deux scripts prennent le même identifiant : `prenom.nom`, en minuscules, sans accent ni espace (un tiret est permis dans le nom). Il sert à calculer des valeurs propres à ton installation. **Utilise exactement le même sur les deux machines**, sinon tes journaux Linux et Windows ne raconteront pas la même nuit.

## Linux : srv-files01

```
sudo apt update && sudo apt install -y git
git clone <adresse du dépôt>
cd <dossier du dépôt>/linux
less setup-srv-files01.sh
sudo bash setup-srv-files01.sh prenom.nom
```

Le script se termine par ton identifiant d'installation. Note-le.

## Windows : DC01

Ouvre PowerShell **en administrateur**, place-toi dans le dossier `windows` du dépôt, puis lance la même commande **trois fois**, avec un redémarrage entre chaque :

```
powershell -ExecutionPolicy Bypass -File .\Setup-DC01.ps1 -Etudiant prenom.nom
```

1. Premier lancement : la machine est renommée `DC01`. Redémarre-la.
2. Deuxième lancement : le domaine `nordrhin.local` est créé. La machine redémarre seule. Ouvre ensuite une session avec `NORDRHIN\Administrateur` (ou `Administrator`).
3. Troisième lancement : comptes, groupes, partage et preuves sont mis en place. Le script se termine par ton identifiant d'installation : il doit être **le même** que sur Linux.

## Juste après

1. Prends un instantané de chaque machine, nommé `P0-depart`.
2. Vérifie que les deux machines se joignent.
3. Lis le fichier `INVENTAIRE.txt` du dossier de preuves de chaque machine.

| Machine | Dossier de preuves |
|---|---|
| `srv-files01` | `/srv/preuves` |
| `DC01` | `C:\Preuves` |

Les journaux archivés citent les adresses de production de l'entreprise (`10.20.0.x`), pas celles de tes machines virtuelles : c'est normal, ce sont des archives.

## Si quelque chose se passe mal

- **Le script refuse de se relancer** : il ne s'exécute qu'une fois. Reviens à l'instantané pris avant le script, ou réinstalle la machine.
- **Erreur pendant le script Linux** : note le message, reviens à l'instantané d'avant, relance. Si l'erreur revient, envoie moi le message complet .
- **La création du domaine échoue** : vérifie l'adresse IP fixe et que le mot de passe du compte Administrateur local est défini.
- **L'évaluation de Windows Server affiche un compte à rebours** : elle dure 180 jours, largement assez pour le projet.

## Ce que ces scripts ne font pas

Ils ne te disent pas ce qui ne va pas. C'est ta phase 1.

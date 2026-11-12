#!/usr/bin/env bash
# Projet NordRhin Distribution - mise en place de srv-files01 (Ubuntu Server 24.04 LTS)
#
# Ce script met la machine dans l'etat de depart du projet : comptes, groupes,
# partage, configurations negligees et journaux archives de l'incident.
# Il n'installe aucun programme malveillant : tout est configuration ou texte.
# A lancer UNE fois, en root, sur une VM dediee au projet. Jamais sur une vraie machine.
#
# Usage : sudo bash setup-srv-files01.sh prenom.nom

set -euo pipefail

MARQUEUR=/etc/nordrhin-projet
PREUVES=/srv/preuves

# ---------------------------------------------------------------- utilitaires
die() { echo "ERREUR : $*" >&2; exit 1; }
info() { echo "[nordrhin] $*"; }

# Valeurs propres a l'etudiant, derivees de son identifiant (meme calcul cote Windows)
calcul_valeurs() {
  local id="$1"
  H=$(printf '%s' "$id" | sha256sum | cut -c1-16)
  b() { echo $((16#${H:$((2 * $1)):2})); }
  ID_INSTALL=${H:0:8}
  IP_ENTREE="198.51.100.$((20 + $(b 0) % 200))"
  local n=$((10 + $(b 1) % 16))
  IP_BRUIT="203.0.113.$n"
  IP_BRUIT2="203.0.113.$((n * 10 + $(b 1) % 6))"
  NB_BRUIT=$((60 + $(b 1) % 40))
  # Entree SSH : 3 novembre 2026, entre 00:30:00 et 00:54:59 UTC (01:30-01:54 heure locale)
  T_ENTREE=$(($(date -u -d '2026-11-03 00:30:00' +%s) + ($(b 2) % 25) * 60 + $(b 3) % 60))
  NB_RH=$((15 + $(b 5) % 20))
  NB_ANCIENS=$((3 + $(b 6) % 4))
}

heure_locale() { TZ=Europe/Paris LC_ALL=C date -d "@$1" '+%b %e %H:%M:%S'; }
heure_utc() { date -u -d "@$1" '+%Y-%m-%dT%H:%M:%SZ'; }

# ------------------------------------------------- journaux archives (texte)
gen_preuves() {
  local dir="$1" tmp i t
  mkdir -p "$dir"
  tmp=$(mktemp)
  local comptes_bruit=(root admin test oracle ubuntu deploy postgres backup)
  local jour=$(date -u -d '2026-11-02 05:00:00' +%s)

  # Bruit de fond : tentatives sans succes depuis Internet
  for ((i = 0; i < NB_BRUIT; i++)); do
    t=$((jour + i * 997 % 79000))
    echo "$t sshd[$((2000 + i))]: Failed password for ${comptes_bruit[i % 8]} from $IP_BRUIT port $((40000 + i)) ssh2"
  done >>"$tmp"
  for ((i = 0; i < 20; i++)); do
    t=$((jour + 3000 + i * 1373 % 79000))
    echo "$t sshd[$((3000 + i))]: Failed password for invalid user ${comptes_bruit[i % 8]} from $IP_BRUIT2 port $((50000 + i)) ssh2"
  done >>"$tmp"
  # Activite normale de la journee
  for i in 0 1 2 3 4 5; do
    t=$((jour + 10800 + i * 4100))
    echo "$t sshd[$((4000 + i))]: Accepted publickey for jschmitt from 10.20.0.31 port $((52000 + i)) ssh2"
  done >>"$tmp"
  echo "$((jour + 12000)) sshd[4100]: Failed password for cmuller from 10.20.0.15 port 51800 ssh2" >>"$tmp"
  echo "$((jour + 30000)) sudo:  jschmitt : TTY=pts/1 ; PWD=/home/jschmitt ; USER=root ; COMMAND=/usr/bin/systemctl restart nr-app" >>"$tmp"

  # La nuit de l'incident
  local e=$T_ENTREE
  {
    echo "$((e - 95)) sshd[5117]: Failed password for deploy from $IP_ENTREE port 51098 ssh2"
    echo "$((e - 61)) sshd[5118]: Failed password for deploy from $IP_ENTREE port 51104 ssh2"
    echo "$((e - 30)) sshd[5119]: Failed password for deploy from $IP_ENTREE port 51110 ssh2"
    echo "$e sshd[5120]: Accepted password for deploy from $IP_ENTREE port 51122 ssh2"
    echo "$((e + 91)) sudo:   deploy : TTY=pts/0 ; PWD=/home/deploy ; USER=root ; COMMAND=/usr/bin/vim /etc/nr-app/app.ini"
    echo "$((e + 369)) useradd[5188]: new user: name=svc-mon, UID=0, GID=0, home=/root, shell=/bin/bash, from=/dev/pts/0"
    echo "$((e + 402)) passwd[5190]: pam_unix(passwd:chauthtok): password changed for svc-mon"
    echo "$((e + 600)) sshd[5231]: Accepted password for svc-mon from $IP_ENTREE port 51340 ssh2"
    echo "$((e + 4100)) sshd[5231]: Disconnected from user svc-mon $IP_ENTREE port 51340"
    # Intervention du prestataire, le matin
    echo "$((e + 29000)) sshd[6400]: Accepted publickey for prestataire from 10.20.0.250 port 53001 ssh2"
    echo "$((e + 29400)) usermod[6412]: lock user 'svc-mon' password"
    echo "$((e + 29460)) usermod[6415]: change user 'deploy' password"
  } >>"$tmp"

  sort -n "$tmp" | while read -r t reste; do
    echo "$(heure_locale "$t") srv-files01 $reste"
  done >"$dir/auth.log"

  # Acces au partage (trace d'audit, en UTC)
  : >"$tmp"
  local rh=(contrat avenant bulletin entretien dossier) dirn=(budget strategie conseil plan)
  for ((i = 0; i < 40; i++)); do
    t=$((jour + 9000 + i * 811 % 36000))
    echo "$t auid=cmuller op=read path=/srv/partage/compta/facture_$((1000 + i)).pdf"
  done >>"$tmp"
  for ((i = 0; i < 25; i++)); do
    t=$((jour + 9500 + i * 1213 % 36000))
    echo "$t auid=lhoffmann op=read path=/srv/partage/direction/${dirn[i % 4]}_$((i % 6 + 1)).docx"
  done >>"$tmp"
  for ((i = 0; i < NB_RH; i++)); do
    echo "$((e + 900 + i * 37)) auid=svc-mon op=read path=/srv/partage/rh/${rh[i % 5]}_$((100 + i)).pdf"
  done >>"$tmp"
  echo "$((e + 880)) auid=svc-mon op=read path=/srv/partage/rh/salaires_2026.csv" >>"$tmp"
  echo "$((e + 2600)) auid=svc-mon op=read path=/srv/partage/rh/salaires_2026.csv" >>"$tmp"
  for ((i = 0; i < 8; i++)); do
    echo "$((e + 2700 + i * 41)) auid=svc-mon op=read path=/srv/partage/direction/${dirn[i % 4]}_$((i % 6 + 1)).docx"
  done >>"$tmp"
  sort -n "$tmp" | while read -r t reste; do echo "$(heure_utc "$t") $reste"; done >"$dir/acces_partage.log"
  rm -f "$tmp"

  cat >"$dir/INVENTAIRE.txt" <<EOF
Dossier de preuves - incident NordRhin Distribution du 3 novembre 2026
Constitue par le prestataire d'intervention. NE PAS MODIFIER : travailler sur une copie.

auth.log            Journal d'authentification de srv-files01 (2 et 3 novembre).
                    Horodatage en heure locale (Europe/Paris, UTC+1 en novembre).
acces_partage.log   Trace d'audit des lectures sur /srv/partage. Horodatage en UTC.
SHA256SUMS          Empreintes des fichiers ci-dessus au moment de l'archivage.

Adresses de production citees dans les journaux :
  srv-files01 = 10.20.0.5      DC01 = 10.20.0.2      postes = 10.20.0.10 a 10.20.0.99
Les journaux de DC01 sont dans C:\\Preuves sur le controleur de domaine.

Actions du prestataire le 3 novembre au matin : compte svc-mon verrouille,
mot de passe de deploy change, outils de l'attaquant retires. Rien d'autre n'a ete corrige.
Identifiant d'installation : $ID_INSTALL
EOF
  (cd "$dir" && sha256sum auth.log acces_partage.log >SHA256SUMS)
}

# ------------------------------------------------------------ etat du systeme
creer_compte() { # nom groupe-secondaire date-dernier-changement
  local nom="$1" grp="$2" date_mdp="$3"
  id "$nom" &>/dev/null || useradd -m -s /bin/bash -G "$grp" "$nom"
  echo "$nom:$(head -c 18 /dev/urandom | base64)" | chpasswd
  chage -d "$date_mdp" "$nom"
}

mise_en_place() {
  info "Nom de machine et paquets de base"
  hostnamectl set-hostname srv-files01
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq acl vim cron >/dev/null

  info "Groupes et comptes"
  for g in compta rh direction logistique; do getent group "$g" >/dev/null || groupadd "$g"; done
  creer_compte cmuller compta 2026-09-14
  creer_compte lhoffmann direction 2026-10-01
  creer_compte nwagner logistique 2024-03-11
  creer_compte jschmitt sudo 2026-10-20
  creer_compte mrichter compta 2026-08-30
  creer_compte stagiaire logistique 2026-09-02
  creer_compte deploy logistique 2023-06-05
  local anciens=(pbraun skeller tvogel amartin dlang gweiss) i
  for ((i = 0; i < NB_ANCIENS; i++)); do creer_compte "${anciens[i]}" logistique "2024-0$((i + 1))-15"; done
  # Compte sans mot de passe
  id test &>/dev/null || useradd -m -s /bin/bash test
  passwd -d test >/dev/null
  # Deux comptes pour un meme identifiant
  id ftp-old &>/dev/null || useradd -o -u "$(id -u lhoffmann)" -g "$(id -g lhoffmann)" -M -s /bin/sh ftp-old
  # Compte cree pendant l'incident, verrouille depuis par le prestataire
  id svc-mon &>/dev/null || useradd -o -u 0 -g 0 -d /root -M -s /bin/bash svc-mon
  passwd -l svc-mon >/dev/null
  usermod -aG adm stagiaire

  info "Delegation de droits"
  cat >/etc/sudoers.d/nordrhin <<'EOF'
# NordRhin Distribution - delegations (derniere revue : 2021)
deploy ALL=(root) NOPASSWD: /usr/bin/systemctl restart nr-app, /usr/bin/vim /etc/nr-app/*
stagiaire ALL=(root) NOPASSWD: /usr/bin/find /srv/partage *
cmuller ALL=(root) /usr/bin/tar -czf /srv/partage/compta/archive.tgz *
lhoffmann ALL=(root) /usr/bin/journalctl -u nr-app
%compta ALL=(root) /usr/bin/lpr
EOF
  chmod 440 /etc/sudoers.d/nordrhin
  visudo -cf /etc/sudoers.d/nordrhin >/dev/null || die "sudoers invalide"

  info "Partage et donnees fictives"
  mkdir -p /srv/partage/{compta,rh,direction,logistique}
  for i in $(seq 1000 1039); do echo "Facture fictive n $i - NordRhin Distribution" >"/srv/partage/compta/facture_$i.pdf"; done
  local rh=(contrat avenant bulletin entretien dossier) dirn=(budget strategie conseil plan)
  for i in $(seq 0 39); do echo "Document RH fictif $i" >"/srv/partage/rh/${rh[i % 5]}_$((100 + i)).pdf"; done
  for n in "${dirn[@]}"; do for i in 1 2 3 4 5 6; do echo "Document de direction fictif" >"/srv/partage/direction/${n}_$i.docx"; done; done
  {
    echo "matricule,nom,service,salaire_brut_annuel"
    for i in $(seq 1 60); do echo "NR$((1000 + i)),Salarie Fictif $i,service$((i % 5)),$((24000 + i * 317))"; done
  } >/srv/partage/rh/salaires_2026.csv
  chown -R root:root /srv/partage
  chgrp -R compta /srv/partage/compta
  chgrp -R rh /srv/partage/rh
  chgrp -R direction /srv/partage/direction
  chmod -R 775 /srv/partage
  chmod 666 /srv/partage/rh/salaires_2026.csv
  chmod 777 /srv/partage/logistique
  echo "planning" >/srv/partage/logistique/planning.txt && chmod 666 /srv/partage/logistique/planning.txt

  info "Application metier (service en echec)"
  id nr-app &>/dev/null || useradd -r -s /usr/sbin/nologin nr-app
  mkdir -p /etc/nr-app /opt/nr-app
  cat >/etc/nr-app/app.ini <<'EOF'
[base]
hote=127.0.0.1
utilisateur=nrapp
mot_de_passe=ChangezMoi2019
EOF
  chown root:root /etc/nr-app/app.ini && chmod 600 /etc/nr-app/app.ini
  cat >/opt/nr-app/nr-app.sh <<'EOF'
#!/bin/sh
[ -r /etc/nr-app/app.ini ] || { echo "nr-app: configuration /etc/nr-app/app.ini illisible" >&2; exit 2; }
exec sleep infinity
EOF
  chmod 755 /opt/nr-app/nr-app.sh
  cat >/etc/systemd/system/nr-app.service <<'EOF'
[Unit]
Description=Application metier NordRhin
[Service]
User=nr-app
ExecStart=/opt/nr-app/nr-app.sh
[Install]
WantedBy=multi-user.target
EOF

  info "Sauvegarde (en echec depuis septembre)"
  cat >/usr/local/sbin/nr-backup.sh <<'EOF'
#!/bin/bash
# Sauvegarde nocturne du partage
set -e
DEST=/mnt/sauvegarde
tar -czf "$DEST/partage_$(date +%F).tar.gz" /srv/partage
EOF
  chmod 777 /usr/local/sbin/nr-backup.sh
  cat >/etc/systemd/system/nr-backup.service <<'EOF'
[Unit]
Description=Sauvegarde du partage NordRhin
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/nr-backup.sh
EOF
  cat >/etc/systemd/system/nr-backup.timer <<'EOF'
[Unit]
Description=Sauvegarde nocturne NordRhin
[Timer]
OnCalendar=*-*-* 01:00:00
[Install]
WantedBy=timers.target
EOF
  mkdir -p /var/backups/nordrhin
  tar -czf /var/backups/nordrhin/partage_2026-09-18.tar.gz /srv/partage/compta 2>/dev/null
  touch -d '2026-09-18 01:00:07' /var/backups/nordrhin/partage_2026-09-18.tar.gz
  systemctl daemon-reload
  systemctl enable --now nr-backup.timer >/dev/null 2>&1
  systemctl enable nr-app >/dev/null 2>&1
  systemctl start nr-app || true
  systemctl start nr-backup.service || true

  info "Mises a jour automatiques, acces distant, pare-feu"
  cat >/etc/apt/apt.conf.d/99nordrhin <<'EOF'
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
EOF
  mkdir -p /etc/ssh/sshd_config.d
  cat >/etc/ssh/sshd_config.d/00-nordrhin.conf <<'EOF'
PermitRootLogin yes
PasswordAuthentication yes
MaxAuthTries 10
EOF
  systemctl reload ssh 2>/dev/null || true
  command -v ufw >/dev/null && ufw --force disable >/dev/null || true

  info "Journaux archives de l'incident"
  gen_preuves "$PREUVES"
  chmod -R a-w "$PREUVES"
}

# ----------------------------------------------------------------------- main
main() {
  [[ $EUID -eq 0 ]] || die "a lancer avec sudo"
  [[ $# -eq 1 && $1 =~ ^[a-z]+\.[a-z-]+$ ]] || die "usage : sudo bash $0 prenom.nom  (minuscules, sans accent)"
  grep -q 'Ubuntu' /etc/os-release || die "ce script est prevu pour Ubuntu Server 24.04 LTS"
  [[ -e $MARQUEUR ]] && die "le script a deja ete lance ici ($(cat $MARQUEUR)). Reviens a ton instantane pour recommencer."
  echo "Ce script va modifier profondement cette machine (comptes, droits, services)."
  read -r -p "Confirmes-tu que c'est une VM dediee au projet ? (oui/non) " rep
  [[ $rep == oui ]] || die "abandon"

  calcul_valeurs "$1"
  mise_en_place
  echo "etudiant=$1 installation=$ID_INSTALL date=$(date -Is)" >"$MARQUEUR"
  echo
  echo "srv-files01 est pret. Preuves : $PREUVES (lis INVENTAIRE.txt)."
  echo "Prends maintenant ton instantane P0-depart."
  echo "IDENTIFIANT D'INSTALLATION : $ID_INSTALL ($1)"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi

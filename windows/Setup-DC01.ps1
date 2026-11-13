<#
Projet NordRhin Distribution - mise en place de DC01 (Windows Server 2022)

Ce script met la machine dans l'etat de depart du projet : domaine nordrhin.local,
comptes, groupes, partage, taches negligees et journaux archives de l'incident.
Il n'installe aucun programme malveillant : tout est configuration ou texte.
A lancer en administrateur, sur la VM dediee au projet. Jamais sur une vraie machine.

Le script se lance TROIS fois, avec un redemarrage entre chaque etape :
  1. renommage de la machine en DC01            -> redemarrage
  2. creation du domaine nordrhin.local         -> redemarrage automatique
  3. comptes, groupes, partage, preuves

Usage : powershell -ExecutionPolicy Bypass -File .\Setup-DC01.ps1 -Etudiant prenom.nom
#>
param([Parameter(Mandatory = $true)][string]$Etudiant)

$ErrorActionPreference = 'Stop'
$Marqueur = 'C:\nordrhin-projet.txt'
$Preuves = 'C:\Preuves'

function Info($m) { Write-Host "[nordrhin] $m" -ForegroundColor Cyan }

if ($Etudiant -cnotmatch '^[a-z]+\.[a-z-]+$') { throw "Usage : -Etudiant prenom.nom (minuscules, sans accent)" }
if (Test-Path $Marqueur) { throw "Le script a deja ete termine ici. Reviens a ton instantane pour recommencer." }

# ------------------------------------------------------------------ etape 1
if ($env:COMPUTERNAME -ne 'DC01') {
    $rep = Read-Host "Ce script va transformer cette machine en controleur de domaine. Est-ce une VM dediee au projet ? (oui/non)"
    if ($rep -ne 'oui') { throw 'Abandon' }
    Info "Etape 1/3 : renommage en DC01"
    Rename-Computer -NewName 'DC01' -Force
    Write-Host "Redemarre la machine (Restart-Computer), puis relance ce script." -ForegroundColor Yellow
    return
}

# ------------------------------------------------------------------ etape 2
$role = (Get-CimInstance Win32_ComputerSystem).DomainRole
if ($role -lt 4) {
    Info "Etape 2/3 : creation du domaine nordrhin.local"
    Write-Host "Avant de continuer : donne une adresse IP FIXE a cette machine." -ForegroundColor Yellow
    $mdp = Read-Host "Choisis un mot de passe de restauration de l'annuaire (note-le)" -AsSecureString
    Install-WindowsFeature AD-Domain-Services, GPMC -IncludeManagementTools | Out-Null
    Install-ADDSForest -DomainName 'nordrhin.local' -DomainNetbiosName 'NORDRHIN' -InstallDns `
        -SafeModeAdministratorPassword $mdp -Force
    return   # la machine redemarre seule ; relancer le script ensuite
}

# ------------------------------------------------------------------ etape 3
Info "Etape 3/3 : etat de depart du domaine"
Import-Module ActiveDirectory

# Valeurs propres a l'etudiant (meme calcul que cote Linux)
$sha = [Security.Cryptography.SHA256]::Create()
$B = $sha.ComputeHash([Text.Encoding]::ASCII.GetBytes($Etudiant))
$IdInstall = -join ($B[0..3] | ForEach-Object { $_.ToString('x2') })
$Epoch0 = [DateTime]::new(2026, 11, 3, 0, 30, 0, [DateTimeKind]::Utc)
$TEntree = $Epoch0.AddSeconds(($B[2] % 25) * 60 + $B[3] % 60)
$NbCibles = 30 + $B[4] % 20
$NbDormants = 6 + $B[6] % 6

function Mdp {
    $c = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789'.ToCharArray()
    $s = -join (1..18 | ForEach-Object { $c | Get-Random })
    ConvertTo-SecureString ("Nr!$s" + '9a') -AsPlainText -Force
}
function Utc($d) { $d.ToString("yyyy-MM-ddTHH:mm:ssZ") }

$dn = (Get-ADDomain).DistinguishedName
$sidDom = (Get-ADDomain).DomainSID.Value
$AdminsDomaine = "$sidDom-512"     # groupe des administrateurs du domaine, quel que soit la langue

Info "Unites d'organisation"
foreach ($ou in 'NordRhin') { New-ADOrganizationalUnit -Name $ou -Path $dn -ProtectedFromAccidentalDeletion $false }
$base = "OU=NordRhin,$dn"
foreach ($ou in 'Utilisateurs', 'Services', 'Groupes', 'Postes', 'Serveurs') {
    New-ADOrganizationalUnit -Name $ou -Path $base -ProtectedFromAccidentalDeletion $false
}

Info "Comptes"
$prenoms = 'hugo', 'david', 'victor', 'jules', 'emma', 'lea', 'nina', 'paul', 'lucas', 'sarah', 'marc', 'anna', 'tom', 'clara', 'louis', 'eva'
$noms = 'roth', 'hahn', 'graff', 'fuchs', 'mayer', 'klein', 'wolff', 'meyer', 'weber', 'schmitt', 'kieffer', 'muller'
$services = 'Comptabilite', 'Logistique', 'Commerce', 'RH', 'Direction'
$salaries = @()
for ($i = 0; $i -lt 44; $i++) {
    $sam = "$($prenoms[$i % 16]).$($noms[($i * 5 + [int]($i / 16)) % 12])"
    if ($salaries.Sam -contains $sam) { continue }
    $salaries += [pscustomobject]@{ Sam = $sam; Service = $services[$i % 5] }
}
foreach ($s in $salaries) {
    New-ADUser -Name $s.Sam -SamAccountName $s.Sam -Department $s.Service -Path "OU=Utilisateurs,$base" `
        -AccountPassword (Mdp) -Enabled $true
}
# Comptes nominatifs et comptes de service
$speciaux = @(
    @{ Sam = 'mrichter'; Desc = 'Responsable comptable'; Ou = 'Utilisateurs'; Nexp = $true },
    @{ Sam = 'cmuller'; Desc = 'Comptabilite'; Ou = 'Utilisateurs'; Nexp = $false },
    @{ Sam = 'jschmitt'; Desc = 'Technicien informatique'; Ou = 'Utilisateurs'; Nexp = $false },
    @{ Sam = 'adm-jschmitt'; Desc = 'Compte d administration de J. Schmitt'; Ou = 'Utilisateurs'; Nexp = $false },
    @{ Sam = 'svc-backup'; Desc = 'Service de sauvegarde'; Ou = 'Services'; Nexp = $true },
    @{ Sam = 'svc-sql'; Desc = 'Service base de donnees'; Ou = 'Services'; Nexp = $true },
    @{ Sam = 'svc-scan'; Desc = 'Scanner multifonction'; Ou = 'Services'; Nexp = $true },
    @{ Sam = 'svc-helpdesk'; Desc = 'Cree le 03/11/2026 - desactive par le prestataire'; Ou = 'Services'; Nexp = $true }
)
foreach ($c in $speciaux) {
    New-ADUser -Name $c.Sam -SamAccountName $c.Sam -Description $c.Desc -Path "OU=$($c.Ou),$base" `
        -AccountPassword (Mdp) -Enabled $true -PasswordNeverExpires $c.Nexp
}
Disable-ADAccount -Identity 'svc-helpdesk'

Info "Groupes (dont une imbrication)"
foreach ($g in 'Comptabilite', 'Logistique', 'Commerce', 'RH', 'Direction', 'Helpdesk-N2') {
    New-ADGroup -Name $g -GroupScope Global -Path "OU=Groupes,$base"
}
foreach ($s in $salaries) { Add-ADGroupMember -Identity $s.Service -Members $s.Sam }
Add-ADGroupMember -Identity 'Comptabilite' -Members 'mrichter', 'cmuller'
Add-ADGroupMember -Identity 'Helpdesk-N2' -Members 'jschmitt', 'mrichter', 'svc-scan', 'svc-helpdesk'
Add-ADGroupMember -Identity $AdminsDomaine -Members 'adm-jschmitt', 'svc-backup', 'Helpdesk-N2'

Info "Politique de mots de passe du domaine (laxiste)"
Set-ADDefaultDomainPasswordPolicy -Identity 'nordrhin.local' -MinPasswordLength 7 -PasswordHistoryCount 0 `
    -MaxPasswordAge ([TimeSpan]::Zero) -MinPasswordAge ([TimeSpan]::Zero) -LockoutThreshold 0

Info "Partage et donnees fictives"
$racine = 'C:\Partages'
foreach ($d in 'Compta', 'RH', 'Direction', 'Logistique') { New-Item -ItemType Directory -Path "$racine\$d" -Force | Out-Null }
1..30 | ForEach-Object { "Facture fictive $_ - NordRhin Distribution" | Set-Content "$racine\Compta\facture_$_.txt" }
1..20 | ForEach-Object { "Document RH fictif $_" | Set-Content "$racine\RH\dossier_$_.txt" }
1..10 | ForEach-Object { "Document de direction fictif $_" | Set-Content "$racine\Direction\note_$_.txt" }
$tous = (New-Object Security.Principal.SecurityIdentifier 'S-1-1-0').Translate([Security.Principal.NTAccount]).Value
New-SmbShare -Name 'Partage' -Path $racine -FullAccess $tous | Out-Null
icacls $racine /grant "*S-1-1-0:(OI)(CI)F" | Out-Null

Info "Sauvegarde planifiee (en echec depuis septembre)"
New-Item -ItemType Directory -Path 'C:\Sauvegardes' -Force | Out-Null
Compress-Archive -Path "$racine\Compta" -DestinationPath 'C:\Sauvegardes\partage_2026-09-18.zip' -Force
(Get-Item 'C:\Sauvegardes\partage_2026-09-18.zip').LastWriteTime = Get-Date '2026-09-18 01:00:09'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -Command "Compress-Archive -Path C:\Partages\* ' +
    '-DestinationPath (''E:\Sauvegardes\partage_'' + (Get-Date -Format yyyy-MM-dd) + ''.zip'') -Force -ErrorAction Stop"')
$decl = New-ScheduledTaskTrigger -Daily -At '01:00'
Register-ScheduledTask -TaskName 'NR-Sauvegarde' -Action $action -Trigger $decl -User 'SYSTEM' -RunLevel Highest | Out-Null
Start-ScheduledTask -TaskName 'NR-Sauvegarde'

Info "Journaux archives de l'incident"
New-Item -ItemType Directory -Path $Preuves -Force | Out-Null
$lignes = New-Object System.Collections.Generic.List[object]
function Evt($date, $texte) { $lignes.Add([pscustomobject]@{ D = $date; T = $texte }) }
$jour = [DateTime]::new(2026, 11, 2, 6, 0, 0, [DateTimeKind]::Utc)

# Activite normale du 2 novembre
for ($i = 0; $i -lt 90; $i++) {
    $s = $salaries[$i % $salaries.Count].Sam
    Evt $jour.AddSeconds($i * 431 % 39000) "EventID=4624 Account=$s Source=10.20.0.$(10 + $i % 60) LogonType=$(2 + ($i % 2))"
}
for ($i = 0; $i -lt 14; $i++) {
    $s = $salaries[($i * 7) % $salaries.Count].Sam
    Evt $jour.AddSeconds(1500 + $i * 2671 % 39000) "EventID=4625 Account=$s Source=10.20.0.$(10 + ($i * 3) % 60) Status=0xC000006A"
}
Evt $jour.AddSeconds(29404) "EventID=4720 Account=emma.stagiaire Source=DC01 SubjectAccount=adm-jschmitt"
Evt $jour.AddSeconds(32529) "EventID=7045 Account=Spooler-Fix Source=DC01 ImagePath=C:\Windows\System32\spoolfix.exe SubjectAccount=adm-jschmitt"

# La nuit de l'incident : essais d'un meme mot de passe sur de nombreux comptes, depuis srv-files01
$t = $TEntree.AddSeconds(2580)
for ($i = 0; $i -lt $NbCibles; $i++) {
    $s = $salaries[($i * 3) % $salaries.Count].Sam
    Evt $t.AddSeconds($i * 58 + $i % 7) "EventID=4625 Account=$s Source=10.20.0.5 Status=0xC000006A"
    if ($i % 6 -eq 2) { Evt $t.AddSeconds($i * 58 + 21) "EventID=4625 Account=$s Source=10.20.0.5 Status=0xC000006A" }
}
$f = $t.AddSeconds($NbCibles * 58 + 40)
Evt $f "EventID=4624 Account=mrichter Source=10.20.0.5 LogonType=3"
Evt $f.AddSeconds(2) "EventID=4672 Account=mrichter Source=10.20.0.5 Privileges=SeDebugPrivilege"
Evt $f.AddSeconds(410) "EventID=4720 Account=svc-helpdesk Source=DC01 SubjectAccount=mrichter"
Evt $f.AddSeconds(448) "EventID=4728 Account=svc-helpdesk Source=DC01 Group=Helpdesk-N2 SubjectAccount=mrichter"
Evt $f.AddSeconds(675) "EventID=7045 Account=NRUpdate Source=DC01 ImagePath=C:\ProgramData\nr\nrupd.exe SubjectAccount=mrichter"
Evt $f.AddSeconds(1359) "EventID=1102 Account=mrichter Source=DC01 Log=Security"
# Intervention du prestataire
Evt $TEntree.AddSeconds(30100) "EventID=4725 Account=svc-helpdesk Source=DC01 SubjectAccount=prestataire"
Evt $TEntree.AddSeconds(30180) "EventID=4724 Account=mrichter Source=DC01 SubjectAccount=prestataire"
Evt $TEntree.AddSeconds(30400) "EventID=7036 Account=NRUpdate Source=DC01 State=removed SubjectAccount=prestataire"

$lignes | Sort-Object D | ForEach-Object { "$(Utc $_.D) $($_.T)" } | Set-Content "$Preuves\security_dc01.log" -Encoding ASCII

# Export de l'annuaire fait par le prestataire (derniere connexion reelle de chaque compte)
$export = @('SamAccountName,Enabled,PasswordNeverExpires,LastLogonDate,Groupes')
$k = 0
foreach ($s in $salaries) {
    if ($k -lt $NbDormants) {
        $ll = if ($k % 3 -eq 0) { 'Never' } else { (Get-Date '2025-01-10').AddDays($k * 37).ToString('yyyy-MM-dd') }
    } else { $ll = (Get-Date '2026-10-20').AddDays($k % 13).ToString('yyyy-MM-dd') }
    $export += "$($s.Sam),True,False,$ll,$($s.Service)"; $k++
}
$export += 'mrichter,True,True,2026-11-03,Comptabilite;Helpdesk-N2'
$export += 'cmuller,True,False,2026-11-02,Comptabilite'
$export += 'jschmitt,True,False,2026-11-02,Helpdesk-N2'
$export += 'adm-jschmitt,True,False,2026-11-02,Domain Admins'
$export += 'svc-backup,True,True,2026-11-03,Domain Admins'
$export += 'svc-sql,True,True,2026-11-03,'
$export += 'svc-scan,True,True,2025-06-12,Helpdesk-N2'
$export += 'svc-helpdesk,False,True,2026-11-03,Helpdesk-N2'
$export | Set-Content "$Preuves\export_annuaire_2026-11-03.csv" -Encoding ASCII

@"
Dossier de preuves - incident NordRhin Distribution du 3 novembre 2026
Constitue par le prestataire d'intervention. NE PAS MODIFIER : travailler sur une copie.

security_dc01.log               Extrait du journal de securite de DC01 (2 et 3 novembre). Horodatage en UTC.
export_annuaire_2026-11-03.csv  Etat des comptes du domaine releve le 3 novembre au matin.
SHA256SUMS.txt                  Empreintes des fichiers ci-dessus au moment de l'archivage.

IMPORTANT : le domaine a ete reinstalle sur ta machine virtuelle. La date de derniere
connexion que tu liras en direct dans l'annuaire est donc vide pour presque tous les comptes.
Pour les dates de derniere connexion REELLES, utilise l'export du prestataire.
Tout le reste (groupes, imbrications, options des comptes, politique) se lit en direct.

Adresses de production citees dans les journaux :
  srv-files01 = 10.20.0.5      DC01 = 10.20.0.2      postes = 10.20.0.10 a 10.20.0.99
Les journaux de srv-files01 sont dans /srv/preuves sur le serveur Linux (heure locale et UTC).

Actions du prestataire le 3 novembre au matin : compte svc-helpdesk desactive,
mot de passe de mrichter reinitialise, service NRUpdate retire. Rien d'autre n'a ete corrige.
Identifiant d'installation : $IdInstall
"@ | Set-Content "$Preuves\INVENTAIRE.txt" -Encoding ASCII

Get-FileHash "$Preuves\security_dc01.log", "$Preuves\export_annuaire_2026-11-03.csv" -Algorithm SHA256 |
    ForEach-Object { "$($_.Hash.ToLower())  $(Split-Path $_.Path -Leaf)" } | Set-Content "$Preuves\SHA256SUMS.txt" -Encoding ASCII
Get-ChildItem $Preuves | ForEach-Object { $_.IsReadOnly = $true }

"etudiant=$Etudiant installation=$IdInstall date=$(Get-Date -Format s)" | Set-Content $Marqueur
Write-Host ""
Write-Host "DC01 est pret. Preuves : $Preuves (lis INVENTAIRE.txt)."
Write-Host "Prends maintenant ton instantane P0-depart."
Write-Host "IDENTIFIANT D'INSTALLATION : $IdInstall ($Etudiant)" -ForegroundColor Green

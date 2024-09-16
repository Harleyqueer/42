#!/bin/bash

CAMPUS_ID=62
START_DATE="2024-09-01T00:00:00.000Z"
END_DATE="2024-10-01T00:00:00.000Z"
BLACKLIST=("bbutcher" "42lhpirate")
CLIENT_ID="u-s4t2ud-b646b0f361dec5dd09ac104e170fb6946d059b426e625e6e11c5629df4c48045"
CLIENT_SECRET="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"

# Obtenir un token d'accès
ACCESS_TOKEN=$(curl -s -X POST --data "grant_type=client_credentials&client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET" https://api.intra.42.fr/oauth/token | jq -r '.access_token')

# Récupérer les données
DATA_1=$(curl -s -G -H "Authorization: Bearer $ACCESS_TOKEN" \
    --data-urlencode "filter[active]=true" \
    --data-urlencode "page[size]=100" \
    --data-urlencode "filter[campus_id]=$CAMPUS_ID" \
    --data-urlencode "range[created_at]=$START_DATE,$END_DATE" \
    "https://api.intra.42.fr/v2/cursus_users")

DATA_2=$(curl -s -G -H "Authorization: Bearer $ACCESS_TOKEN" \
    --data-urlencode "filter[active]=true" \
    --data-urlencode "page[size]=100" \
    --data-urlencode "page[number]=2" \
    --data-urlencode "filter[campus_id]=$CAMPUS_ID" \
    --data-urlencode "range[created_at]=$START_DATE,$END_DATE" \
    "https://api.intra.42.fr/v2/cursus_users")

DATA=$(echo "$DATA_1 $DATA_2" | jq -s '.[0] + .[1]')

# Préparer les données
declare -a students_info

logins=$(echo "$DATA" | jq -r '.[] | .user.login')
correction_points=$(echo "$DATA" | jq -r '.[] | .user.correction_point')
levels=$(echo "$DATA" | jq -r '.[] | .level')

index=0
while IFS= read -r login && IFS= read -r correction_point <&3 && IFS= read -r level <&4; do
    if [[ " ${BLACKLIST[@]} " =~ " $login " ]]; then
        continue
    fi
    [[ "$level" == "null" || -z "$level" ]] && level=0

    # Formater le niveau avec 2 chiffres après la virgule
    level_formatted=$(printf "%.2f" "$level")

    user_url="https://profile.intra.42.fr/users/$login"
    students_info+=("$level_formatted $login $correction_point $user_url")
    index=$((index + 1))
done < <(printf "%s\n" "$logins") 3< <(printf "%s\n" "$correction_points") 4< <(printf "%s\n" "$levels")

# Trier les étudiants par niveau en ordre décroissant
sorted_info=$(printf "%s\n" "${students_info[@]}" | sort -nr | awk '{print $0}')

# Créer un fichier HTML avec un meilleur design
cat <<EOF > leaderboard.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Leaderboard</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
            background-color: #eaf2f8; /* Bleu pastel */
            color: #333;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
            box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
            background-color: #ffffff;
        }
        th, td {
            border: 1px solid #b0c4de; /* Bleu pastel clair pour les bordures */
            padding: 12px;
            text-align: left;
        }
        th {
            background-color: #aeeeee; /* Bleu pastel */
            color: #000000;
        }
        tr:nth-child(even) {
            background-color: #f0f8ff; /* Bleu très clair */
        }
        tr:hover {
            background-color: #e0ffff; /* Bleu très clair au survol */
        }
        h1 {
            color: #4682b4; /* Bleu moyen */
        }
        .rank {
            text-align: center;
            color: #4682b4; /* Bleu moyen */
        }
    </style>
</head>
<body>
    <h1>Leaderboard</h1>
    <table>
        <thead>
            <tr>
                <th>Rank</th>
                <th>Login</th>
                <th>Level</th>
                <th>EP (Correction Points)</th>
            </tr>
        </thead>
        <tbody>
EOF

# Ajouter les données triées au fichier HTML avec classement et liens
rank=1
while IFS= read -r line; do
    level=$(echo "$line" | awk '{print $1}')
    login=$(echo "$line" | awk '{print $2}')
    correction_point=$(echo "$line" | awk '{print $3}')
    user_url=$(echo "$line" | awk '{print $4}')
    
    # Écrire une ligne dans le tableau HTML avec classement et lien hypertexte
    cat <<EOF >> leaderboard.html
            <tr>
                <td class="rank">$rank</td>
                <td><a href="$user_url" target="_blank">$login</a></td>
                <td>$level</td>
                <td>$correction_point</td>
            </tr>
EOF
    rank=$((rank + 1))
done <<< "$sorted_info"

# Terminer le fichier HTML
cat <<EOF >> leaderboard.html
        </tbody>
    </table>
</body>
</html>
EOF

# Ouvrir le fichier HTML avec le navigateur par défaut
xdg-open leaderboard.html 2>/dev/null || open leaderboard.html 2>/dev/null

echo "Fichier HTML généré et ouvert : leaderboard.html"

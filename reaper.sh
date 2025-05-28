
#!/usr/bin/env bash
export PATH=$PATH:/home/kali/go/bin # This is needed or waybackurls doesn't work

echo ""
echo "Don't fear the..."
echo " ██▀███  ▓█████ ▄▄▄       ██▓███  ▓█████  ██▀███  "
echo "▓██ ▒ ██▒▓█   ▀▒████▄    ▓██░  ██▒▓█   ▀ ▓██ ▒ ██▒"
echo "▓██ ░▄█ ▒▒███  ▒██  ▀█▄  ▓██░ ██▓▒▒███   ▓██ ░▄█ ▒"
echo "▒██▀▀█▄  ▒▓█  ▄░██▄▄▄▄██ ▒██▄█▓▒ ▒▒▓█  ▄ ▒██▀▀█▄  "
echo "░██▓ ▒██▒░▒████▒▓█   ▓██▒▒██▒ ░  ░░▒████▒░██▓ ▒██▒"
echo "░ ▒▓ ░▒▓░░░ ▒░ ░▒▒   ▓▒█░▒▓▒░ ░  ░░░ ▒░ ░░ ▒▓ ░▒▓░"
echo "  ░▒ ░ ▒░ ░ ░  ░ ▒   ▒▒ ░░▒ ░      ░ ░  ░  ░▒ ░ ▒░"
echo "  ░░   ░    ░    ░   ▒   ░░          ░     ░░   ░ "
echo "   ░        ░  ░     ░  ░            ░  ░   ░     "
echo ""
echo ""

# Instantiate Global Variables
url=$1
date=$(date +%Y-%m-%d)
dir_name="${url}_${date}"

echo "┌──────────────────────────────┐"
echo "|  CREATE DIRECTORIES & FILES  │"
echo "└──────────────────────────────┘"

echo "[+] Preparing directories and files..."

# Directories to create
directories=(
    "$dir_name"
    "$dir_name/subdomains"
    "$dir_name/httprobe"
    "$dir_name/potential_takeovers"
    "$dir_name/nmap"
    "$dir_name/wayback"
    "$dir_name/wayback/params"
    "$dir_name/wayback/extensions"
)

# Loop to create directories if they don't exist
for dir in "${directories[@]}"; do
    [ ! -d "$dir" ] && mkdir -p "$dir"
done

# Files to create
files=(
    "$dir_name/reaper_output.txt"
    "$dir_name/subdomains/assetfinder.txt"
    "$dir_name/subdomains/assetfinder_grep.txt"
    "$dir_name/subdomains/amass.txt"
    "$dir_name/subdomains/amass_grep.txt"
    "$dir_name/subdomains/final.txt"
    "$dir_name/httprobe/alive.txt"
    "$dir_name/httprobe/alive_dev.txt"
    "$dir_name/httprobe/alive_test.txt"
    "$dir_name/httprobe/alive_stag.txt"
    "$dir_name/httprobe/alive_admin.txt"
    "$dir_name/potential_takeovers/potential_takeovers.txt"
    "$dir_name/wayback/wayback_output.txt"
    "$dir_name/wayback/params/wayback_params.txt"
    "$dir_name/wayback/extensions/js.txt"
    "$dir_name/wayback/extensions/jsp.txt"
    "$dir_name/wayback/extensions/json.txt"
    "$dir_name/wayback/extensions/php.txt"
    "$dir_name/wayback/extensions/aspx.txt"
)

# Track terminal output
exec > >(tee -a "$dir_name/reaper_output.txt") 2>&1

# Loop to create files if they don't exist
for file in "${files[@]}"; do
    dir=$(dirname "$file")  # Extract directory part of the path
    [ ! -d "$dir" ] && mkdir -p "$dir"  # Create the directory if it doesn't exist
    [ ! -f "$file" ] && touch "$file"  # Create the file if it doesn't exist
done

# Clean out the output files if they exist
for file in "${files[@]}"; do
    > "$file"
done


echo "[+] Directories and files ready."

echo "┌──────────────────────────────┐"
echo "│     SUBDOMAIN HARVESTING     |"
echo "|         ASSETFINDER          │"
echo "└──────────────────────────────┘"

echo "[+] Harvesting subdomains with assetfinder..."

timeout 5m assetfinder "$url" >> "$dir_name/subdomains/assetfinder.txt"
if [ $? -eq 124 ]; then
  echo "[-] assetfinder timed out after 5 minutes..."
  if [ ! -s "$dir_name/subdomains/assetfinder.txt" ]; then
    echo "[!] assetfinder.txt is empty"
  fi
  echo "[+] Continuing..."
else
  echo "[+] assetfinder harvesting complete."
fi
grep "$url" "$dir_name/subdomains/assetfinder.txt" > "$dir_name/subdomains/assetfinder_grep.txt"


echo "┌──────────────────────────────┐"
echo "│     SUBDOMAIN HARVESTING     |"
echo "|            AMASS             │"
echo "└──────────────────────────────┘"

echo "[+] Harvesting subdomains with amass..."

timeout 5m amass enum -d "$url" >> "$dir_name/subdomains/amass.txt"

if [ $? -eq 124 ]; then
  echo "[-] amass timed out after 5 minutes..."
  if [ ! -s "$dir_name/subdomains/amass.txt" ]; then
    echo "[!] amass.txt is empty"
  fi
  echo "[+] Continuing..."
else
  echo "[+] amass harvesting complete."
fi
grep "$url" "$dir_name/subdomains/amass.txt" | awk '{print $1; print $NF}' | sed 's/ (FQDN)//' | sort -u > "$dir_name/subdomains/amass_grep.txt"



echo "┌──────────────────────────────┐"
echo "│ CREATE FINAL SUBDOMAIN LIST  │"
echo "└──────────────────────────────┘"

# Combine the grep.txt files into final.txt, even if one is empty
echo "[+] Combining harvests into final.txt..."

# Append assetfinder grep results if not empty
if [ -s "$dir_name/subdomains/assetfinder_grep.txt" ]; then
    cat "$dir_name/subdomains/assetfinder_grep.txt" >> "$dir_name/subdomains/final.txt"
else
    echo "[!] No content in assetfinder_grep.txt"
fi

# Append amass grep results if not empty
if [ -s "$dir_name/subdomains/amass_grep.txt" ]; then
    cat "$dir_name/subdomains/amass_grep.txt" >> "$dir_name/subdomains/final.txt"
else
    echo "[!] No content in amass_grep.txt"
fi

# Sort and remove duplicates
sort -u "$dir_name/subdomains/final.txt" -o "$dir_name/subdomains/final.txt"

if [ -s "$dir_name/subdomains/final.txt" ]; then
    echo "[+] final.txt has been created and contains data."
else
    echo "[!] final.txt is empty."
fi


echo "┌──────────────────────────────┐"
echo "│           HTTPROBE           │"
echo "└──────────────────────────────┘"

echo "[+] Finding live subdomains with httprobe..."

cat "$dir_name/subdomains/final.txt" | httprobe | sed 's|http[s]*://||' | sort -u > "$dir_name/httprobe/alive.txt"

# Grep out interesting subdomains
cat $dir_name/httprobe/alive.txt | grep dev > $dir_name/httprobe/alive_dev.txt
cat $dir_name/httprobe/alive.txt | grep test > $dir_name/httprobe/alive_test.txt
cat $dir_name/httprobe/alive.txt | grep stag > $dir_name/httprobe/alive_stag.txt
cat $dir_name/httprobe/alive.txt | grep admin > $dir_name/httprobe/alive_admin.txt

echo "[+] Live subdomains harvested."


echo "┌──────────────────────────────┐"
echo "│      SUBDOMAIN TAKEOVER      │"
echo "└──────────────────────────────┘"

echo "[+] Checking for possible subdomain takeover..."

subjack -w $dir_name/subdomains/final.txt -t 100 -timeout 30 -ssl -c /usr/share/subjack/fingerprints.json -v 3 -o $dir_name/potential_takeovers/potential_takeovers.txt

echo "[+] Subdomain takeover check complete."


echo "┌──────────────────────────────┐"
echo "│           NMAP SCAN          │"
echo "└──────────────────────────────┘"

# Delete all files in the scans directory before starting the scan
echo "[+] Cleaning scans directory..."
rm -f $dir_name/nmap/*

echo "[+] Scanning for open ports..."
timeout 5m nmap -T4 -p- -A -iL $dir_name/httprobe/alive.txt -oA $dir_name/nmap/nmap > /dev/null 2>&1
if [ $? -eq 124 ]; then
  echo "[-] nmap timed out after 5 minutes...continuing."
else
  echo "[+] nmap scan complete"
fi

echo "┌──────────────────────────────┐"
echo "│        WAYBACK MACHINE       │"
echo "└──────────────────────────────┘"

# Debug wayback if needed
if ! which waybackurls > /dev/null 2>&1; then
  echo "[!] waybackurls not found"
  echo "[!] PATH inside script: $PATH"
fi

echo "[+] Scraping wayback data..."
cat $dir_name/subdomains/final.txt | waybackurls >> $dir_name/wayback/wayback_output.txt
sort -u $dir_name/wayback/wayback_output.txt

echo "[+] Pulling and compiling all possible params found in wayback data..."
cat $dir_name/wayback/wayback_output.txt | grep '?*=' | cut -d '=' -f 1 | sort -u >> $dir_name/wayback/params/wayback_params.txt
for line in $(cat $dir_name/wayback/params/wayback_params.txt);do echo $line'=';done

echo "[+] Pulling and compiling js/php/aspx/jsp/json files from wayback output..."
for line in $(cat $dir_name/wayback/wayback_output.txt);do
	ext="${line##*.}"
	if [[ "$ext" == "js" ]]; then
		echo $line >> $dir_name/wayback/extensions/js1.txt
		sort -u $dir_name/wayback/extensions/js1.txt >> $dir_name/wayback/extensions/js.txt
	fi
	if [[ "$ext" == "html" ]];then
		echo $line >> $dir_name/wayback/extensions/jsp1.txt
		sort -u $dir_name/wayback/extensions/jsp1.txt >> $dir_name/wayback/extensions/jsp.txt
	fi
	if [[ "$ext" == "json" ]];then
		echo $line >> $dir_name/wayback/extensions/json1.txt
		sort -u $dir_name/wayback/extensions/json1.txt >> $dir_name/wayback/extensions/json.txt
	fi
	if [[ "$ext" == "php" ]];then
		echo $line >> $dir_name/wayback/extensions/php1.txt
		sort -u $dir_name/wayback/extensions/php1.txt >> $dir_name/wayback/extensions/php.txt
	fi
	if [[ "$ext" == "aspx" ]];then
		echo $line >> $dir_name/wayback/extensions/aspx1.txt
		sort -u $dir_name/wayback/extensions/aspx1.txt >> $dir_name/wayback/extensions/aspx.txt
	fi
done

echo "┌──────────────────────────────┐"
echo "│       REAPING COMPLETE       │"
echo "└──────────────────────────────┘"

echo "[+] ${dir_name} has been reaped. The harvest is plentiful; enjoy the spoils."

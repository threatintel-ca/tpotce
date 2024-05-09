#!/bin/bash

# Let's ensure normal operation on exit or if interrupted ...
function fuCLEANUP {
	exit 0
}
trap fuCLEANUP EXIT

# Source ENVs from file ...
if [ -f "/data/tpot/etc/compose/elk_environment" ]; then
	echo "Found .env, now exporting ..."
	set -o allexport && source "/data/tpot/etc/compose/elk_environment" && set +o allexport
fi

# Check internet availability
function fuCHECKINET() {
	mySITES=$1
	error=0
	for i in $mySITES; do
		curl --connect-timeout 5 -Is $i 2>&1 >/dev/null
		if [ $? -ne 0 ]; then
			let error+=1
		fi
	done
	echo $error
}

# Check for connectivity and download latest translation maps
myCHECK=$(fuCHECKINET "listbot.sicherheitstacho.eu")
if [ "$myCHECK" == "0" ]; then
	echo "Connection to Listbot looks good, now downloading latest translation maps."
	cd /etc/listbot
	aria2c -s16 -x 16 https://listbot.sicherheitstacho.eu/cve.yaml.bz2 &&
		aria2c -s16 -x 16 https://listbot.sicherheitstacho.eu/iprep.yaml.bz2 &&
		bunzip2 -f *.bz2
	cd /
else
	echo "Cannot reach Listbot, starting Logstash without latest translation maps."
fi

sed -i 's/THREATINTEL_ES_HOST/'"$THREATINTEL_ES_HOST"'/g' /etc/logstash/logstash.conf
sed -i 's/THREATINTEL_ES_INDEX/'"$THREATINTEL_ES_INDEX"'/g' /etc/logstash/logstash.conf
sed -i 's/THREATINTEL_ES_APIKEY/'"$THREATINTEL_ES_APIKEY"'/g' /etc/logstash/logstash.conf
sed -i 's/THREATINTEL_ES_SSL_MODE/'"$THREATINTEL_ES_SSL_MODE"'/g' /etc/logstash/logstash.conf

exec /usr/share/logstash/bin/logstash --config.reload.automatic

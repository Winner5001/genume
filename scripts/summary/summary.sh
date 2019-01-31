#!/bin/bash
os=''
temp=`hostnamectl | grep "Operating System"`
os=${temp#*: }
if [ -z "$os" ]; then
	os="UNKNOWN"
fi

kernel=''
kernel=`uname -r`
if [ -z "$kernel" ]; then
	kernel="UNKNOWN"
fi

uptime=''
uptime=$(</proc/uptime)
uptime=${uptime//.*}
mins=$((uptime/60%60))
hours=$((uptime/3600%24))
days=$((uptime/86400))
uptime="${mins}m"
if [ "${hours}" -ne "0" ]; then
	uptime="${hours}h ${uptime}"
fi
if [ "${days}" -ne "0" ]; then
	uptime="${days}d ${uptime}"
fi
if [ -z "$uptime" ]; then
	uptime="UNKNOWN"
fi

packages=''
packages=`dpkg -l | grep -c '^i'`
if [ -z "$packages" ]; then
	packages="UNKNOWN"
fi

resolution=''
resolution=`xdpyinfo | awk '/dimensions:/ { print $2 }'`
if [ -z "$resolution" ]; then
	resolution="UNKNOWN"
fi

cpu=''
cpu=$(awk -F':' '/^model name/ {split($2, A, " @"); print A[1]; exit}' /proc/cpuinfo)
cpun=$(grep -c '^processor' /proc/cpuinfo)
if [ -z "$cpu" ]; then
	cpu=$(awk 'BEGIN{FS=":"} /Hardware/ { print $2; exit }' /proc/cpuinfo)
fi
if [ -z "$cpu" ]; then
	cpu=$(awk 'BEGIN{FS=":"} /^cpu/ { gsub(/  +/," ",$2); print $2; exit}' /proc/cpuinfo | sed 's/, altivec supported//;s/^ //')
	if [[ $cpu =~ ^(PPC)*9.+ ]]; then
		model="IBM PowerPC G5 "
	elif [[ $cpu =~ 740/750 ]]; then
		model="IBM PowerPC G3 "
	elif [[ $cpu =~ ^74.+ ]]; then
		model="Motorola PowerPC G4 "
	elif [[ $cpu =~ ^POWER.* ]]; then
		model="IBM POWER "
	elif grep -q -i 'BCM2708' /proc/cpuinfo ; then
		model="Broadcom BCM2835 ARM1176JZF-S"
	else
		arch=$(uname -m)
		if [[ "$arch" == "s390x" || "$arch" == "s390" ]]; then
			cpu=""
			args=$(grep 'machine' /proc/cpuinfo | sed 's/^.*://g; s/ //g; s/,/\n/g' | grep '^machine=.*')
			eval "$args"
			case "$machine" in
				# information taken from https://github.com/SUSE/s390-tools/blob/master/cputype
				2064) model="IBM eServer zSeries 900" ;;
				2066) model="IBM eServer zSeries 800" ;;
				2084) model="IBM eServer zSeries 990" ;;
				2086) model="IBM eServer zSeries 890" ;;
				2094) model="IBM System z9 Enterprise Class" ;;
				2096) model="IBM System z9 Business Class" ;;
				2097) model="IBM System z10 Enterprise Class" ;;
				2098) model="IBM System z10 Business Class" ;;
				2817) model="IBM zEnterprise 196" ;;
				2818) model="IBM zEnterprise 114" ;;
				2827) model="IBM zEnterprise EC12" ;;
				2828) model="IBM zEnterprise BC12" ;;
				2964) model="IBM z13" ;;
				   *) model="IBM S/390 machine type $machine" ;;
			esac
		else
			model="Unknown"
		fi
	fi
	cpu="${model}${cpu}"
fi
loc="/sys/devices/system/cpu/cpu0/cpufreq"
bl="${loc}/bios_limit"
smf="${loc}/scaling_max_freq"
if [ -f "$bl" ] && [ -r "$bl" ]; then
	cpu_mhz=$(awk '{print $1/1000}' "$bl")
elif [ -f "$smf" ] && [ -r "$smf" ]; then
	cpu_mhz=$(awk '{print $1/1000}' "$smf")
else
	cpu_mhz=$(awk -F':' '/cpu MHz/{ print int($2+.5) }' /proc/cpuinfo | head -n 1)
fi
if [ -n "$cpu_mhz" ]; then
	if [ "${cpu_mhz%.*}" -ge 1000 ]; then
		cpu_ghz=$(awk '{print $1/1000}' <<< "${cpu_mhz}")
		cpufreq="${cpu_ghz}GHz"
	else
		cpufreq="${cpu_mhz}MHz"
	fi
fi
if [[ "${cpun}" -gt "1" ]]; then
	cpun="${cpun}x "
else
	cpun=""
fi
if [ -z "$cpufreq" ]; then
	cpu="${cpun}${cpu}"
else
	cpu="$cpu @ ${cpun}${cpufreq}"
fi
if [ -d '/sys/class/hwmon/' ]; then
	for dir in /sys/class/hwmon/* ; do
		hwmonfile=""
		[ -e "$dir/name" ] && hwmonfile=$dir/name
		[ -e "$dir/device/name" ] && hwmonfile=$dir/device/name
		[ -n "$hwmonfile" ] && if grep -q 'coretemp' "$hwmonfile"; then
			thermal="$dir/temp1_input"
			break
		fi
	done
	if [ -e "$thermal" ] && [ "${thermal:+isSetToNonNull}" = 'isSetToNonNull' ]; then
		temperature=$(bc <<< "scale=1; $(cat "$thermal")/1000")
	fi
fi
if [ -n "$temperature" ]; then
	cpu="$cpu [${temperature}°C]"
fi
cpu=$(sed $REGEXP 's/\([tT][mM]\)|\([Rr]\)|[pP]rocessor|CPU//g' <<< "${cpu}" | xargs)
if [ -z "$cpu" ]; then
	cpu="UNKNOWN"
fi

mem=''
mem=`free -b | awk 'NR==2{print $2"-"$7}'`
usedmem=$((mem / 1024 / 1024))
totalmem=$((${mem//-*} / 1024 / 1024))
mem="${usedmem}MiB / ${totalmem}MiB"
if [ -z "$mem" ]; then
	mem="UNKNOWN"
fi


echo VALUE BAS OS: \"${os}\"
echo VALUE BAS KERNEL: \"$kernel\"
echo VALUE BAS UPTIME: \"$uptime\"
echo VALUE BAS PACKAGES: \"$packages\"
echo VALUE BAS RESOLUTION: \"$resolution\"
echo VALUE BAS CPU: \"$cpu\"
echo VALUE BAS MEMORY: \"$mem\"

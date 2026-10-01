#!/bin/bash

# script to be run periodically to store on the local redis database the
#  state of the host's clock synchronization, so that it is accessible to
#  any other redis client and reaches clickhouse on last0 through
#  redis_to_clickhouse.service (the whitelist entry 'last*' already covers
#  these keys)
#
# Companion of hostinfo-redis.sh, but on its own slower timer: that one runs
#  every 5s and is tuned to ~54ms, while timedatectl is a DBus round trip and
#  there is no cheap file to read for timesyncd state. Sampling faster than
#  the NTP poll (PollIntervalMaxSec, 256s on the nodes) gains nothing anyway.
#
# redis_to_clickhouse only stores a value when it CHANGES, so the offset
#  produces about one row per actual NTP measurement rather than one per
#  sample. Offsets and jitter are therefore quantized (QUANTUM_US) so that a
#  quiet clock stops generating rows altogether; 10us is 100x below the 1ms
#  warning threshold used by the nightly report, so nothing of interest is
#  lost.
#
# Values are stored as BARE NUMBERS in fixed units (microseconds for times,
#  ppm for the frequency correction): changingHashDetector.py routes a value
#  to operation_numbers only when json.loads() yields a number, and
#  timedatectl prints mixed units ('+889us', '-1.172ms'), which would land in
#  operation_strings and leave the units to be parsed by the reader.
#  clockServer is deliberately a string - it changes only when the host falls
#  back off the primary server, so it costs ~no rows and is the alert we want.

QUANTUM_US=10            # offset/jitter rounding, microseconds
STALL_SAMPLES=5          # consecutive samples with no new NTP packet => stalled
STATE=${STATE:-/run/last-clockinfo.state}   # overridable so the script can be run by hand

# Convert a timedatectl duration ('+889us', '-1.172ms', '22us', '1.5s', '0')
#  to an integer number of microseconds. Prints nothing if unparsable, so the
#  caller can skip the key rather than publish a wrong number.
function to_us() {
    local v="${1}" sign=1 num unit
    [ -z "${v}" ] && return
    case "${v}" in
        +*) v="${v#+}" ;;
        -*) v="${v#-}"; sign=-1 ;;
    esac
    # a bare '0' carries no unit
    if [[ ${v} =~ ^0+(\.0+)?$ ]]; then echo 0; return; fi
    num="${v%%[a-zµ]*}"
    unit="${v#"${num}"}"
    [[ ${num} =~ ^[0-9]+(\.[0-9]+)?$ ]] || return
    case "${unit}" in
        s)        awk -v n="${num}" -v s="${sign}" 'BEGIN{printf "%d", s*n*1000000}' ;;
        ms)       awk -v n="${num}" -v s="${sign}" 'BEGIN{printf "%d", s*n*1000}' ;;
        us|µs)    awk -v n="${num}" -v s="${sign}" 'BEGIN{printf "%d", s*n}' ;;
        ns)       awk -v n="${num}" -v s="${sign}" 'BEGIN{printf "%d", s*n/1000}' ;;
        *)        return ;;
    esac
}

function quantize() {
    [ -z "${1}" ] && return
    awk -v v="${1}" -v q="${QUANTUM_US}" 'BEGIN{printf "%d", int(v/q + (v>=0?0.5:-0.5))*q}'
}

function publish() {
    # publish <metric> <value>; skips empty values rather than storing junk
    [ -z "${2}" ] && return
    redis-cli hset "${HOSTNAME}.${1}" t "$(date +%s.%N)" v "${2}" > /dev/null
}

status=$(timedatectl timesync-status 2>/dev/null)
show=$(timedatectl show-timesync 2>/dev/null)

# A host with timesyncd stopped or never synchronized has no status block at
#  all. Publish the fact (clockSynced=0) and stop: there are no numbers to
#  report, and silently publishing nothing would be indistinguishable from a
#  dead collector.
if [ -z "${status}" ]; then
    publish clockSynced 0
    exit 0
fi

offset=$(quantize "$(to_us "$(awk '/^ *Offset:/{print $2}' <<< "${status}")")")
jitter=$(quantize "$(to_us "$(awk '/^ *Jitter:/{print $2}' <<< "${status}")")")
rootdist=$(to_us "$(awk '/^ *Root distance:/{print $3}' <<< "${status}")")
stratum=$(awk '/^ *Stratum:/{print $2}' <<< "${status}")

server=$(sed -n 's/^ServerName=//p' <<< "${show}")
# an unnamed server (IP only in the config) still deserves an identity
[ -z "${server}" ] && server=$(sed -n 's/^ServerAddress=//p' <<< "${show}")
packets=$(grep -o 'PacketCount=[0-9]*' <<< "${show}" | cut -d= -f2)
freq=$(sed -n 's/^Frequency=//p' <<< "${show}")

synced=$(timedatectl show --property=NTPSynchronized --value 2>/dev/null)
[ "${synced}" = "yes" ] && synced=1 || synced=0

# The kernel frequency correction is in 65536-ppm units; store ppm, rounded to
#  0.01 so that the slow hunting of the control loop does not generate a row
#  on every single poll.
if [ -n "${freq}" ]; then
    freq=$(awk -v f="${freq}" 'BEGIN{printf "%.2f", f/65536}')
fi

# Liveness: PacketCount legitimately does not advance between samples (we
#  sample faster than the poll interval), so only a run of unchanged readings
#  longer than the maximum poll means timesyncd is actually wedged. Without
#  this, a stuck daemon looks exactly like a stable clock - the offset simply
#  stops changing, and the dedup means it stops producing rows too.
stalled=0
if [ -n "${packets}" ]; then
    prev_packets=''; prev_count=0
    [ -r "${STATE}" ] && read -r prev_packets prev_count < "${STATE}" 2>/dev/null
    if [ "${packets}" = "${prev_packets}" ]; then
        prev_count=$((prev_count + 1))
        (( prev_count >= STALL_SAMPLES )) && stalled=1
    else
        prev_count=0
    fi
    echo "${packets} ${prev_count}" > "${STATE}" 2>/dev/null || true
fi

publish clockOffset        "${offset}"
publish clockJitter        "${jitter}"
publish clockRootDistance  "${rootdist}"
publish clockStratum       "${stratum}"
publish clockFreq          "${freq}"
publish clockServer        "${server}"
publish clockSynced        "${synced}"
publish clockPacketsStalled "${stalled}"

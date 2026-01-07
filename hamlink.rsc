# ============================================================
# Ham-Link Autoconfig v10 (star-driven roles)
#
# NEU (wichtig):
#   - KEINE Board/Device-Unterscheidung mehr (kein RB911/PowerBox-Pro Match).
#   - Gerätetyp wird NUR aus der Topologie-Note abgeleitet:
#       * genau 1 Stern (*)  -> RADIO (QRT / mit WLAN)  -> konfiguriert WLAN+Bridge
#       * kein Stern (*)     -> SWITCH (PowerBox)       -> konfiguriert nur Bridge-Ports + (optional) PoE
#       * >1 Stern           -> Fehler
#
# STAR RULES (wenn Stern vorhanden):
#   - First element (left end)  may ONLY be "NAME*"   (A-side marker)
#   - Last  element (right end) may ONLY be "*NAME"   (B-side marker)
#   - Middle elements may be "*NAME" or "NAME*"
#
# IDENTITY (wenn Stern vorhanden):
#   - "NAME*" => NAME-A
#   - "*NAME" => NAME-B
#
# NEIGHBOR / HOP (wenn Stern vorhanden):
#   - role A => connect RIGHT neighbor (hop index = starIdx)
#   - role B => connect LEFT  neighbor (hop index = starIdx - 1)
#
# SWITCH MODE (kein Stern):
#   - Identität bleibt unverändert (kein /system identity set)
#   - Es wird nur eine Bridge gebaut und Ether-Ports hinzugefügt
#   - PoE wird "best-effort" via /interface ethernet set <iface> poe-out=auto-on gesetzt
#
# SSID (GLOBAL, based on PATH ENDPOINTS):
#   HAMNET(<LEFT_END><=><RIGHT_END>)
#
# RF PARAMS via globals:
#   :global hamlinkFrequencies   "5500,5520,5540"
#   :global hamlinkTxPowerDbm    0|17                ; 0 => do not force fixed power
#   :global hamlinkChannelWidth  "5mhz"
#   :global hamlinkDfsMode       "skip" | "allow"
# ============================================================

:log warning "HAMLINK: start (superchannel)"

:local HAMLINKTAG "HAMLINK"

# ----------------------------
# 1) Read globals
# ----------------------------
:log info "HAMLINK:S1 read globals"
:global hamlinkStationId
:global hamlinkFrequencies
:global hamlinkTxPowerDbm
:global hamlinkChannelWidth
:global hamlinkDfsMode

:local pStation $hamlinkStationId

:local freqListStr $hamlinkFrequencies
:if ([:len $freqListStr] = 0) do={ :set freqListStr "5500,5520,5540" }

:local txp $hamlinkTxPowerDbm
:if ([:len $txp] = 0) do={ :set txp 0 }

:local chWidth $hamlinkChannelWidth
:if ([:len $chWidth] = 0) do={ :set chWidth "5mhz" }

:local dfsMode $hamlinkDfsMode
:if ([:len $dfsMode] = 0) do={ :set dfsMode "skip" }

:local skipDfsParam "all"
:if ($dfsMode = "allow") do={ :set skipDfsParam "disabled" }

:log warning ("HAMLINK:S1 stationId='" . $pStation . "' freqs='" . $freqListStr . "' txp=" . $txp . " width=" . $chWidth . " dfsMode=" . $dfsMode . " skipDfs=" . $skipDfsParam)

# ----------------------------
# 2) Read + normalize topology from system note
# ----------------------------
:log info "HAMLINK:S2 read system note"
:local note [/system note get note]
:log warning ("HAMLINK:S2 raw note='" . $note . "' len=" . [:len $note])
:if ([:len $note] = 0) do={ :error "HAMLINK: system note is empty. Set note like A*<->B<->C (radio) or A<->B (switch)" }

# normalize: remove spaces, CR, LF
:local p -1

:log info "HAMLINK:S2.1 remove spaces"
:set p [:find $note " "]
:while (($p != nil) && ($p >= 0)) do={
  :set note ([:pick $note 0 $p] . [:pick $note ($p + 1) [:len $note]])
  :set p [:find $note " "]
}

:log info "HAMLINK:S2.2 remove CR"
:set p [:find $note "\r"]
:while (($p != nil) && ($p >= 0)) do={
  :set note ([:pick $note 0 $p] . [:pick $note ($p + 1) [:len $note]])
  :set p [:find $note "\r"]
}

:log info "HAMLINK:S2.3 remove LF"
:set p [:find $note "\n"]
:while (($p != nil) && ($p >= 0)) do={
  :set note ([:pick $note 0 $p] . [:pick $note ($p + 1) [:len $note]])
  :set p [:find $note "\n"]
}

:log warning ("HAMLINK:S2 normalized note='" . $note . "' len=" . [:len $note])
/system note set note=$note show-at-login=yes

# ----------------------------
# 3) Parse topology note "A<->B<->C"
# ----------------------------
:log info "HAMLINK:S3 parse topology"
:local nodes []
:local s $note

:while ([:len $s] > 0) do={
  :local fp [:find $s "<->"]
  :if (($fp = nil) || ($fp < 0)) do={
    :set nodes ($nodes, $s)
    :set s ""
  } else={
    :set nodes ($nodes, [:pick $s 0 $fp])
    :set s [:pick $s ($fp + 3) [:len $s]]
  }
}

:local nCnt [:len $nodes]
:log warning ("HAMLINK:S3 nodes count=" . $nCnt)
:for i from=0 to=($nCnt-1) do={ :log info ("HAMLINK:S3 node[" . $i . "]='" . ($nodes->$i) . "'") }

:if ($nCnt < 2) do={ :error ("HAMLINK: topology needs >=2 nodes, got: " . $note) }

# ----------------------------
# 3.1) Determine GLOBAL endpoints for SSID (strip any '*')
# ----------------------------
:log info "HAMLINK:S3.1 endpoints + SSID"
:local leftEnd ($nodes->0)
:local rightEnd ($nodes->($nCnt - 1))

:if ([:pick $leftEnd 0 1] = "*") do={ :set leftEnd [:pick $leftEnd 1 [:len $leftEnd]] }
:if ([:pick $leftEnd ([:len $leftEnd]-1) [:len $leftEnd]] = "*") do={ :set leftEnd [:pick $leftEnd 0 ([:len $leftEnd]-1)] }

:if ([:pick $rightEnd 0 1] = "*") do={ :set rightEnd [:pick $rightEnd 1 [:len $rightEnd]] }
:if ([:pick $rightEnd ([:len $rightEnd]-1) [:len $rightEnd]] = "*") do={ :set rightEnd [:pick $rightEnd 0 ([:len $rightEnd]-1)] }

:if ([:len $leftEnd] = 0 || [:len $rightEnd] = 0) do={ :error "HAMLINK: endpoints empty after stripping '*'" }

:local ssid ("HAMNET(" . $leftEnd . "<=>" . $rightEnd . ")")
:log warning ("HAMLINK:S3.1 leftEnd=" . $leftEnd . " rightEnd=" . $rightEnd . " ssid=" . $ssid)

# ----------------------------
# 4) Count '*' across ALL nodes => decide mode
# ----------------------------
:log info "HAMLINK:S4 count stars + decide mode"
:local starIdx -1
:local starCount 0

:for i from=0 to=($nCnt - 1) do={
  :local e ($nodes->$i)

  :local j 0
  :while ($j < [:len $e]) do={
    :if ([:pick $e $j ($j+1)] = "*") do={ :set starCount ($starCount + 1) }
    :set j ($j + 1)
  }

  :local hasStar [:find $e "*"]
  :if (($hasStar != nil) && ($hasStar >= 0)) do={
    :if ($starIdx != -1) do={ :error "HAMLINK: '*' found in more than one element. For RADIO exactly one element must be marked; for SWITCH no '*' at all." }
    :set starIdx $i
  }
}

:log warning ("HAMLINK:S4 starCount=" . $starCount . " starIdx=" . $starIdx)

:local isRadio false
:if ($starCount = 1) do={ :set isRadio true }
:if (($starCount != 0) && ($starCount != 1)) do={ :error ("HAMLINK: invalid '*': expected 0 (switch) or 1 (radio), found " . $starCount) }


# ----------------------------
# 5) CLEANUP: NUR HAMLINK-OBJEKTE (via comment "HAMLINK")
#     (und wireless security-profiles "hamlink-*")
# ----------------------------
:log warning "HAMLINK:S5 cleanup begin (HAMLINK-only)"

# Wireless menu exists?
:local hasWireless false
:do { :if ([:len [/interface wireless find]] > 0) do={ :set hasWireless true } } on-error={ :set hasWireless false }

# Wireless: disable only if present (safe)
:if ($hasWireless = true) do={
  :do { /interface wireless disable [find] } on-error={ :log warning "HAMLINK:S5 wireless disable failed/unsupported" }
}

# Wireless security-profiles: delete ONLY hamlink-*
:if ($hasWireless = true) do={
  :do {
    :foreach sp in=[/interface wireless security-profiles find] do={
      :local n [/interface wireless security-profiles get $sp name]
      :if ([:pick $n 0 8] = "hamlink-") do={
        /interface wireless security-profiles remove $sp
        :log info ("HAMLINK:S5 removed security-profile " . $n)
      }
    }
  } on-error={ :log warning "HAMLINK:S5 security-profiles cleanup failed/unsupported" }
}

# Bridge ports: remove 
:do {
  :local bp [/interface bridge port find where bridge="br-hamlink"]
  :if ([:len $bp] > 0) do={ /interface bridge port remove $bp }
  :local b [/interface bridge find where name="br-hamlink"]
  :if ([:len $b] > 0) do={ /interface bridge remove $b }
} on-error={
  :log warning ("REMOVE failed: " . $message)
}


# IP addresses: remove 
:local ipA [/ip address find]
:if ([:len $ipA] > 0) do={ /ip address remove $ipA }

# DHCP client/server/network: remove 
:local dhc [/ip dhcp-client find]
:if ([:len $dhc] > 0) do={ /ip dhcp-client remove $dhc }

:local dhs [/ip dhcp-server find]
:if ([:len $dhs] > 0) do={ /ip dhcp-server remove $dhs }

:local dhn [/ip dhcp-server network find]
:if ([:len $dhn] > 0) do={ /ip dhcp-server network remove $dhn }

# Firewall: remove 
:local ff [/ip firewall filter find]
:if ([:len $ff] > 0) do={ /ip firewall filter remove $ff }

:local fn [/ip firewall nat find]
:if ([:len $fn] > 0) do={ /ip firewall nat remove $fn }

:local fm [/ip firewall mangle find]
:if ([:len $fm] > 0) do={ /ip firewall mangle remove $fm }

# Static routes: remove 
:local rt [/ip route find where static=yes]
:if ([:len $rt] > 0) do={ /ip route remove $rt }

:log warning "HAMLINK:S5 cleanup done"

# ----------------------------
# 6) Build common bridge (tagged)
# ----------------------------
:log info "HAMLINK:S6 create bridge"
:local brName "br-hamlink"
/interface bridge add name=$brName protocol-mode=rstp comment=("HAMLINK " . $leftEnd . "<->" . $rightEnd)

# ------------------------------------------------------------
# Configure base bridge
# ------------------------------------------------------------
:log warning "HAMLINK:S7 SWITCH mode"

# Add ALL ethernet ports (best-effort)
:foreach eId in=[/interface ethernet find] do={

:local e [/interface ethernet get $eId name]

/interface bridge port add bridge=$brName interface=$e \
  comment=("HAMLINK " . $e . " " . $leftEnd . "<->" . $rightEnd)

:log info ("HAMLINK: added switch port " . $e)
}

:log warning "HAMLINK: finished (SWITCH mode)"
:put "=================================================="
:put ("HAMLINK SWITCH STATUS @ " . [/system clock get date] . " " . [/system clock get time])
:put ("note: " . $note)
:put ("bridge: " . $brName)
:log warning "HAMLINK: done"


# End here if we are not a radio
:if ($isRadio = false) do={
  :log warning "Config finished."
  :return ""
}


# ------------------------------------------------------------
# RADIO MODE (exactly one '*'): treat as QRT/wireless node
# ------------------------------------------------------------

# Find starred element and validate star rules
:log info "HAMLINK:S8 RADIO derive role/identity"

:local elem ($nodes->$starIdx)
:local isLeft false
:local isRight false
:if ([:pick $elem 0 1] = "*") do={ :set isLeft true }
:if ([:pick $elem ([:len $elem]-1) [:len $elem]] = "*") do={ :set isRight true }

:if ($isLeft && $isRight) do={ :error "HAMLINK: invalid element: '*' cannot be on both sides (*NAME*)." }
:if ((!$isLeft) && (!$isRight)) do={ :error "HAMLINK: invalid element: '*' must be at start or end (*NAME or NAME*)." }

:if (($starIdx = 0) && (!$isRight)) do={ :error "HAMLINK: first element may only be NAME* (A-side)." }
:if (($starIdx = ($nCnt - 1)) && (!$isLeft)) do={ :error "HAMLINK: last element may only be *NAME (B-side)." }

:local selfBase $elem
:if ($isLeft)  do={ :set selfBase [:pick $selfBase 1 [:len $selfBase]] }
:if ($isRight) do={ :set selfBase [:pick $selfBase 0 ([:len $selfBase]-1)] }
:if ([:len $selfBase] = 0) do={ :error "HAMLINK: local base name empty after stripping '*'." }

:local role ""
:if ($isRight) do={ :set role "A" } else={ :set role "B" }

# Optional sanity-check vs hamlinkStationId
:if ([:len $pStation] > 0) do={
  :local st $pStation
  :local stLen [:len $st]
  :if ($stLen < 3) do={ :error "HAMLINK: hamlinkStationId too short (expected NAME-A/NAME-B)" }

  :local dash [:pick $st ($stLen - 2)]
  :local rch  [:pick $st ($stLen - 1)]
  :if (($dash != "-") || (($rch != "A") && ($rch != "B"))) do={ :error "HAMLINK: hamlinkStationId must end with -A or -B" }

  :local baseFromParam [:pick $st 0 ($stLen - 2)]
  :if ($baseFromParam != $selfBase) do={ :error ("HAMLINK: hamlinkStationId base '" . $baseFromParam . "' != starred element '" . $selfBase . "'") }
  :if ($rch != $role) do={ :error ("HAMLINK: hamlinkStationId role '" . $rch . "' != star-derived role '" . $role . "'") }
}

:local finalId ($selfBase . "-" . $role)
/system identity set name=$finalId
:local id $finalId
:log warning ("HAMLINK: RADIO identity=" . $id)

# Neighbor + hop
:local neighbor ""
:local linkIdx 0
:if ($role = "A") do={
  :if ($starIdx >= ($nCnt - 1)) do={ :error ("HAMLINK: " . $id . " is -A but has no RIGHT neighbor in topology") }
  :set neighbor ($nodes->($starIdx + 1))
  :set linkIdx $starIdx
} else={
  :if ($starIdx = 0) do={ :error ("HAMLINK: " . $id . " is -B but has no LEFT neighbor in topology") }
  :set neighbor ($nodes->($starIdx - 1))
  :set linkIdx ($starIdx - 1)
}

:if ([:pick $neighbor 0 1] = "*") do={ :set neighbor [:pick $neighbor 1 [:len $neighbor]] }
:if ([:pick $neighbor ([:len $neighbor]-1) [:len $neighbor]] = "*") do={ :set neighbor [:pick $neighbor 0 ([:len $neighbor]-1)] }

:local aName ""
:local bName ""
:if ($role = "A") do={ :set aName $selfBase; :set bName $neighbor } else={ :set aName $neighbor; :set bName $selfBase }

:local linkName ($aName . "--" . $bName)
:local wpaKey $linkName

# Frequency pool
:local freqs []
:local t $freqListStr
:while ([:len $t] > 0) do={
  :local c [:find $t ","]
  :if (($c = nil) || ($c < 0)) do={ :set freqs ($freqs, $t); :set t "" } else={ :set freqs ($freqs, [:pick $t 0 $c]); :set t [:pick $t ($c + 1) [:len $t]] }
}
:local freqCount [:len $freqs]
:if ($freqCount < 1) do={ :error "HAMLINK: hamlinkFrequencies is empty after parsing" }

:local selIdx ($linkIdx % $freqCount)
:local freq ($freqs->$selIdx)
:if ([:len $freq] = 0) do={ :error ("HAMLINK: empty frequency at selIdx " . $selIdx) }


# Ensure all wifi ports in bridge
# Ensure all wifi ports in bridge (legacy /interface wireless)
:do {
  :foreach wId in=[/interface wireless find] do={

    :local w [/interface wireless get $wId name]

    /interface bridge port add bridge=$brName interface=$w \
      comment=("HAMLINK " . $w . " " . $leftEnd . "<->" . $rightEnd)

    :log info ("HAMLINK: added wifi port " . $w)
  }
} on-error={
  :log info "HAMLINK: no legacy wireless menu / no wifi ports"
}

# Wireless must exist in RADIO mode
:if ($hasWireless = false) do={ :error "HAMLINK: RADIO mode but no /interface wireless present" }
:if ([:len [/interface wireless find where name="wlan1"]] = 0) do={ :error "HAMLINK: RADIO mode but missing wlan1" }
:if ([:len [/interface ethernet find where name="ether1"]] = 0) do={ :error "HAMLINK: RADIO mode but missing ether1" }

# Security profile
:local secName ("hamlink-" . $linkName)
/interface wireless security-profiles add name=$secName \
  authentication-types=wpa2-psk \
  wpa2-pre-shared-key=$wpaKey \
  unicast-ciphers=aes-ccm group-ciphers=aes-ccm \
  management-protection=disabled comment=("HAMLINK " . $linkName)

:local mode "station-bridge"
:if ($role = "A") do={ :set mode "ap-bridge" }

/interface wireless set wlan1 country=no_country_set
/interface wireless set wlan1 frequency-mode=superchannel

:if ($txp > 0) do={
  /interface wireless set wlan1 \
    ssid=$ssid mode=$mode band=5ghz-a/n channel-width=$chWidth wireless-protocol=802.11 \
    frequency=$freq skip-dfs-channels=$skipDfsParam security-profile=$secName \
    tx-power-mode=all-rates-fixed tx-power=$txp wps-mode=disabled disabled=no \
    comment=("HAMLINK " . $leftEnd . "<->" . $rightEnd . " hop=" . $linkIdx . " " . $role)
} else={
  /interface wireless set wlan1 \
    ssid=$ssid mode=$mode band=5ghz-a/n channel-width=$chWidth wireless-protocol=802.11 \
    frequency=$freq skip-dfs-channels=$skipDfsParam security-profile=$secName \
    wps-mode=disabled disabled=no \
    comment=("HAMLINK " . $leftEnd . "<->" . $rightEnd . " hop=" . $linkIdx . " " . $role)
}

# Diagnostics
:put "=================================================="
:put ("HAMLINK RADIO STATUS @ " . [/system clock get date] . " " . [/system clock get time])
:put ("identity: " . $id)
:put ("topology(note): " . $note)
:put ("global ssid: " . $ssid)
:put ("role: " . $role . " | neighbor: " . $neighbor)
:put ("hop index: " . $linkIdx)
:put ("hop link: " . $linkName)
:put ("wpa2-psk: " . $wpaKey)
:put ("rf: selected freq=" . $freq . " (pool idx " . $selIdx . ") width=" . $chWidth . " dfsMode=" . $dfsMode . " (skip-dfs-channels=" . $skipDfsParam . ") txPower(dBm)=" . $txp)
:put ("bridge: " . $brName)
:put "Bridge ports:"
/interface bridge port print where bridge=$brName

:put "Wireless monitor (wlan1):"
/interface wireless monitor wlan1 once
:put "Wireless registration-table:"
/interface wireless registration-table print

:log warning "HAMLINK: finished (RADIO mode)"

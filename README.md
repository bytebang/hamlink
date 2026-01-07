# hamlink
Eine **einfache, strukturierte und modular aufgebaute Layer-2-Point-to-Point-Datenbrücke** für den schnellen Einsatz.

---

## Zielsetzung (Scope)

Im Rahmen des **SKKM** besteht regelmäßig die Anforderung, **kurzfristig Datenverbindungen zwischen zwei Standorten** aufzubauen (Point-to-Point). Diese Verbindung kann dabei:

- **direkt** zwischen zwei Standorten bestehen oder
- **über eine oder mehrere Zwischenstationen (Relais)** realisiert werden.

Die Zwischenstationen sind **nicht vermascht**, sondern **streng linear** hintereinandergeschaltet.  
Es existieren **keine Schleifen**.

Daraus ergeben sich folgende Eigenschaften:

- Die **Gesamtleistung** der Verbindung entspricht der Leistung des **schwächsten Links**
- Die **Verfügbarkeit** sinkt indirekt proportional mit der Anzahl der Zwischenknoten
- **Zuverlässigkeit und Robustheit** stehen klar vor maximaler Bandbreite

Es kann **nicht vorausgesetzt werden**, dass alle beteiligten Personen über tiefgehende Kenntnisse von Netzwerktechnik oder Router-Konfigurationen verfügen.  
Daher folgt Ham-Link konsequent dem Prinzip:

> **Convention over Configuration**

---

## Anwendungsszenarien

Typische Einsatzszenarien sind:

- Bereitstellung eines **Hamnet-Zugangs**, der an entfernte Standorte weitergereicht werden soll
- Nutzung der Verbindung durch **mehrere Einsatzorganisationen**, ohne dass deren Datenströme vermischt werden  
  (Layer-2-Separation, z. B. mittels VLANs, darf nicht behindert werden)

---

## Nicht im Scope (Out-of-Scope)

- **Kryptographische Absicherung der Datenübertragung**  
  Die Ham-Link-Infrastruktur transportiert Daten **unverschlüsselt**.  
  Es liegt in der Verantwortung der Endanwender, bei Bedarf **End-to-End-Verschlüsselung** einzusetzen.

---

## Rollenmodell

Obwohl **identische Hardware** eingesetzt wird, unterscheiden sich die Stationen in ihrer **funktionalen Rolle**.

Grundregel:

> Für eine funktionierende Funkverbindung zwischen A und B ist immer eine **gerade Anzahl aktiver Funkkomponenten** erforderlich.

### A-Station

Eine **A-Station** ist funktional näher am „Kernnetz“ bzw. Internet angebunden.

Typische Eigenschaften:

- Station einer Einsatzorganisation
- Notstromversorgter Rechner oder Netzanschluss vorhanden
- Zielpunkt der Datenübertragung

### B-Station

Eine **B-Station** befindet sich weiter in der Peripherie.

Typische Eigenschaften:

- Einsatzort
- Ursprung der Daten
- Übertragung Richtung Leit- oder A-Station

> Obwohl die Begriffe A und B eine Richtung suggerieren, ist der Datenverkehr **immer bidirektional**.

### Z-Station (Zwischenstation)

Eine **Z-Station** ist eine **Relaisstation**, bestehend aus:

- einer A-Station und
- einer B-Station

am selben Standort, jedoch mit **unterschiedlicher Antennenausrichtung**.

Sie nimmt Daten entgegen und leitet diese transparent weiter.

---

## Mögliche Topologien

### Direkte Verbindung

~~~
[A] - [B]
~~~

### Verbindung über eine Zwischenstation

~~~
[A] - [Z] - [B]
~~~

### Mehrere Zwischenstationen

~~~
[A] - [Z] - [Z] - [B]
...
~~~
Verbindung zwischen A und B über Z1 und Z2. Ist einer der Links unterbrochen bricht die ganze Verbindung zusammen.


### Namensgebungen

Aus diesen Rollen und den Standorten lassen sich die Namen der Stationen sowie der Links ableiten.

**Stationsnamen** setzen sich immer aus dem Standort oder dem Operatorkuerzel sowie der Rolle der Station zusammen. Beim Standort Empfiehlt es sich einen GridLocator einzutragen - das hat den Charme das man danach auch die [Antennenausrichtung](https://afu-base.de/knife/index.php) berechnen kann

Der vollständige Name hat nicht mehr als 10 Zeichen, und besteht ausschließlich aus Großbuchstaben, Ziffern und dem Zeichen `/`. 
Der hintangestellte Suffix `-A` oder `-B` kennzeichnet dann die Rolle der Station.

Hier einige gültige Beispiele:

`OE6GUE-A` oder `OE6HUD/AM-A` oder z.B: bei einer Z Station: `JN77KK77rl-A` und `JN77KK77rl-B` oder geografisch `RENNFELD-A`.


**Links** ... also die Verbindung zwischen zwei Stationen tragen den Namen des A und B Links (ohne den Suffix) mit zwei Bindestrichen getrennt. Hier ein Beispiel wenn die A Station RENNFELD-A und die B Station OE6GUE-B heisst -> Dann wäre der Name des Links `RENNFELD--OE6GUE`. Es ist anzumerken das die Reihenfolge hier relevant ist, weil man daraus eben den A Teil (links) und B Teil (rechts) der Verbindung ableiten kann.

## Regeln

Die Gesamte Konfiguration besteht aus wenigen einfachen Regeln welche hier definiert sind:

* Es werden ausschließlich transparente Layer2 Links erstellt. (D.h wenn IP Adressen erforderlich sind, dann haben die am Ende befindlichen A und B Stationen diese selbst bereitzustellen (z.B. aus einer Hamnet IP-(Block)zuweisung)

* A Stationen sind immer in der Betriebsart _AP_ und B Stationen immer als _Station_ zu betreiben. Somit findet technisch gesehen der Verbindungsaufbau von B zu A statt.

* Auf allen Stationen ist immer die selbe SSID zu verwenden. Sie beginnt mit dem Prefix `HAMLINK(` und dem Kuerzel des zuständigen Operators der ganz linken Seite, dem fixen Symbol `<=>`, dem Endoperator auf der ganz rechten Seite un dann der fixen Zeichen `)`. Somit ergeben sich z.B: folgende Bezeichnungen `HAMLINK(OE6XLR<=>JN77MI)` oder `HAMLINK(OE6GUE-A<=>JN77KK77rl)`

* Damit keine Schleifen und Fehlkonfigurationen zu Stande kommen wird jeder Link mit einem eigenen WPA2 Passwort gesichert. Das Passwort entspricht dem Namen des Links (z.B: `RENNFELD--OE6GUE` wenn Rennfeld die A Station und OE6GUE die B Station ist)

* Die System Identity sollte dem Stationsnamen entsprechen. 


## Hardware-Konzept

Die eingesetzte Hardware ist weitgehend **vereinheitlicht** und arbeitet in den für den Amateurfunk zulässigen Frequenz- und Leistungsbereichen.

Jede Station verfügt über einen **5-Port-Switch** mit fest definierter Port-Funktion:

| Port | Funktion |
|------|---------|
| eth1 | Management / Administration |
| eth2 + eth3 | Funkgeräte (Antennen), PoE + Daten |
| eth4 + eth5 | Einsatznetz, **immer reserviert**, PoE aktiv |

Eine **korrekte Verkabelung** ist Voraussetzung für einen störungsfreien Betrieb.

---

## Stationstypen im Detail

### A- / B-Station

Besteht aus:

- **1× PowerBox Pro**
- **1× QRT5**

Die Spannungsversorgung erfolgt über die PowerBox Pro.

- Ruhestrom: ca. **6 W**
- Maximal: **54 W**
- Versorgung über:
  - DC-Buchse **oder**
  - passives PoE an eth1
- Eingangsspannung: **12–57 V DC**
- **Kein Verpolschutz!**

---

### Z-Station

Besteht aus:

- **1× PowerBox Pro**
- **2× QRT5**

Die Stromversorgung erfolgt identisch zu A/B-Stationen.  
Optional können **zwei 12-V-Akkus in Serie (24 V)** verwendet werden.

- eth2 + eth3: Funkgeräte
- eth4 + eth5: meist ungenutzt

## Provisioning

Um die Hardware entsprechend zu konfigurieren sind viele manuelle Schritte notwendig. Das ist i.d.R. recht fehleranfällig - weshalb ich hier ein Script zur Verfügung stelle die Scripts für die ensprecheden Geräte erstellt. Diese müssen dann nur mehr in die MikroTik Geräte eingespielt werden. Das kann einerseits mit [netinstall](https://help.mikrotik.com/docs/spaces/ROS/pages/24805390/Netinstall) oder auch händisch erfolgen.

Dabei muss lediglich die System Identity eingegeben werden (damit das System weiß wer es ist) und in der System Note der Systemaufbau skizziert werden. Das config Script konfiguriert das Gerät dann dementsprechend.

So sind auf dem Gerät "HOME" folgende Schritte notwendig
~~~
# Hamlink Struktur setzen
/system note set note="HOME*<->RELAIS<->REMOTE"

# Config Script ausführen
/system script run hamlink
~~~


Am Relais dann auf den QRTs

~~~
/system note set note="HOME*<->RELAIS<->REMOTE" show-at-login=yes
/system script run hamlink
~~~

~~~
/system note set note="HOME<->*RELAIS<->REMOTE" show-at-login=yes
/system script run hamlink
~~~

~~~
/system note set note="HOME<->RELAIS*<->REMOTE" show-at-login=yes
/system script run hamlink
~~~

Und am REMOTE dann ... 

~~~
/system note set note="HOME<->RELAIS<->*REMOTE" show-at-login=yes
/system script run hamlink
~~~


Das Script `hamlink` setzt alle Parameter entsprechend ...


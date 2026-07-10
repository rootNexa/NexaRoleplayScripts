# nexa_robberies

`nexa_robberies` beschreibt realistische offene Raub-Foundations fuer Laeden, Tankstellen, ATMs, Banken, Juweliere, Einbrueche und Fahrzeugdiebstahl-Integration.

Die Resource delegiert Sessions, Reputation, Heat und Responderregeln an `nexa_crime`. Loot wird serverseitig beansprucht und mit Idempotency vorbereitet. Fahrzeugdiebstahl bedeutet keinen freien Ownership-Wechsel.

## Bank, Jeweller und Burglary

Bank, Juwelier und Einbruch sind als offene Foundations modelliert: Bereiche, Phasen, Alarm, Lootpunkte, Reset und Recovery kommen aus serverseitigen Definitionen. Es gibt keine geskripteten Missionsfinales und keine freie Client-Entscheidung ueber Vault, Cases oder Property-Loot.

## Vehicle Theft, Loot und Stolen Items

Vehicle Theft erzeugt Crime-, Heat- und Evidence-Kontext, aber keinen freien Ownership-Wechsel. Loot-Claims sind idempotent, phasegebunden und bereiten gestohlene Item-Metadata fuer Hehler, Evidence und Recovery vor.

# Billing Migration Plan

1. `nexa_billing` als neue Foundation einfuehren.
2. Legacy-Rechnungsquellen dokumentieren und einfrieren.
3. Neue Rechnungen nur ueber `nexa_billing` erzeugen.
4. Zahlungen nur ueber `nexa_economy` buchen.
5. Storno und Gutschrift historisch modellieren.
6. Banking-/Phone-/UI-Anbindungen spaeter auf neue API umstellen.

Keine automatische Migration bestehender Rechnungen in Kapitel 10.

# Payroll Duty Time

Payroll bewertet echte Duty-Sessions aus `nexa_job_duty_sessions`, nicht den Momentzustand.

Sessions werden auf Periodengrenzen beschnitten, offene Sessions bis zum Abrechnungszeitpunkt gerechnet und ueberlappende Zeit nicht doppelt gezaehlt.

Clientzeit wird nie verwendet.

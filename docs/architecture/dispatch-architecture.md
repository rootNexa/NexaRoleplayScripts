# Dispatch Architecture

`nexa_dispatch` verwaltet Notrufe, Einsaetze, Einheitenstatus, GPS-Kontext, Alarmierung und Adapter.

Crime, Medical, Police und spaetere Systeme melden Ereignisse ueber Adapter oder interne Events, nicht ueber harte Reverse-Dependencies.

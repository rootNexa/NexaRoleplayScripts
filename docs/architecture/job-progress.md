# Job Progress

Progress-Modelle:

- boolean
- count
- percentage
- distance
- duration
- quantity
- checkpoint_sequence

Progress ist monotonic, rate-limited und versioniert, wenn der Tasktyp dies verlangt. Clients liefern nur Beobachtungen; der Server validiert.

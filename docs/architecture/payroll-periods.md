# Payroll Periods

Perioden haben Start, Ende, Scope, Status und optional Run-ID.

Status: `open`, `calculating`, `ready`, `processing`, `completed`, `failed`, `manual_review`.

Perioden duerfen sich im selben Scope nicht ueberlappen und muessen idempotent erzeugt werden.

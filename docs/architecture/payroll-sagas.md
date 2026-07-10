# Payroll Sagas

Payroll verwendet idempotente Run- und Entry-Keys. Jeder Entry verweist auf Economy-Transaction-ID.

Unklare Teilzustaende werden `manual_review`, nicht automatisch negativ gebucht.

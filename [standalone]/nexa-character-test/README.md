# nexa-character-test

Development-only server command tests for `nexa-character`.

## Commands

- `/nexacharlist`
- `/nexacharcreate`
- `/nexacharselect <id>`
- `/nexacharactive`

In development mode the commands are enabled for local testing. Outside development mode, player commands require `nexa.admin`.

`/nexacharcreate` uses fixed test data:

```lua
first_name = 'Test'
last_name = 'Character'
birthdate = '2000-01-01'
gender = 'unknown'
```

The resource does not access the database directly and only calls `nexa-character` and `nexa-core` exports.

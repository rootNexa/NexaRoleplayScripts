# Admin Freeze

Freeze state is server-authoritative and stored in memory for online players.

Disconnect and resource stop clear freeze state. The client only applies `FreezeEntityPosition` after receiving a server event.

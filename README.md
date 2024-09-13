# Rex

Proof of Concept Elixir implementation of Cardano's Ouroboros networking mini-protocols.

## Running

Run the following command using your own Cardano node's socket path:

```bash
NODE_SOCKET_PATH=/your/cardano/node.socket mix query_current_era
```

🚨 The N2C protocol on the Haskell cardano-node only works via Unix socket. It does not allow connection through an IP or hostname.

## Setting up Unix socket mapping

1. Run socat on the remote server with the following command:

```bash
socat TCP-LISTEN:3002,reuseaddr,fork UNIX-CONNECT:/home/cardano_node/socket/node.socket
```

2. Run socat on the local machine with the following command:

```bash
socat UNIX-LISTEN:/tmp/cardano_node.socket,reuseaddr,fork TCP:localhost:3002
```

3. Start an SSH tunnel from the local machine to the remote server with the following command:

```bash
ssh -N -L 3002:localhost:3002 user@remote-server-ip
```

## Catalyst Proposal

F12 proposal for further development of this project:
https://cardano.ideascale.com/c/idea/122664

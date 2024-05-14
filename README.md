# Rex

Proof of Concept Elixir implementation of Cardano's Ouroboros networking mini-protocols.

## Running

Run the following command, using your Cardano node's socket file:

```bash
NODE_SOCKET_PATH=/your/cardano/node.socket mix run -e "Rex.get_current_era"
```

Catalyst F12 Proposal for further development of this project:
https://cardano.ideascale.com/c/idea/122664

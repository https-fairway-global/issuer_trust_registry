# Issuer Trust Registry Smart Contract (fairway/issuer_trust_registry)

This Aiken project implements an on-chain trust registry using a single state UTXO managed by a designated curator. It stores a Merkle root representing the state of trusted issuers, allowing for efficient verification of issuer status off-chain.

## Contract Overview

The contract uses a single state UTXO pattern. One UTXO locked at the script address holds the current Merkle root of the registered issuers. Updates involve consuming this UTXO and producing a new one with the updated Merkle root.

### Parameters

The validator is parameterized at compile time with the curator's public key hash:

*   `curator_pkh: VerificationKeyHash`: The hash of the verification key belonging to the curator authorized to update the registry's Merkle root.

### Datum (`RegistryState`)

The single state UTXO holds the following datum:

*   `merkle_root: ByteArray`: The Merkle root hash representing the current set of registered issuers and their details. The specific structure of the Merkle tree (e.g., how issuer DIDs, names, credential types are included) is defined off-chain.

### Redeemer (`Action`)

To update the Merkle root, the curator must submit a transaction that spends the state UTXO, providing the following redeemer:

*   `UpdateRoot { new_root: ByteArray }`: Used to replace the existing `merkle_root` with a new one.

### Logic (`spend` handler)

The core logic resides in the `spend` handler, which validates attempts to spend the state UTXO:

1.  **Curator Signature:** The transaction *must* be signed by the key corresponding to the `curator_pkh` parameter.
2.  **Datum Presence:** The UTXO being spent *must* contain a valid `RegistryState` datum.
3.  **Action Dispatch:** The logic validates the `UpdateRoot` action:
    *   Ensures exactly one output is sent back to the script address (the continuing state UTXO).
    *   Verifies the output datum is a `RegistryState`.
    *   Verifies the `merkle_root` in the output datum matches the `new_root` provided in the redeemer.
    *   Ensures the Ada value (and any other tokens) in the output is greater than or equal to the input value (value preservation).

## Building

To compile the validator and generate the `plutus.json` blueprint:

```bash
aiken build
```

## Testing

*(Placeholder: Tests will be added to verify the validator logic)*

To run tests:

```bash
aiken check
```

## Usage

1.  **Instantiation:** Build the contract (`aiken build`) and apply the `curator_pkh` parameter to the generated blueprint to get the script address.
2.  **Initialization:** The curator sends an initial transaction locking a UTXO (e.g., containing minimum Ada) at the script address. The transaction must include the initial `RegistryState` datum (inline) containing the starting Merkle root (e.g., a root representing an empty registry).
3.  **Updating the Root:** The curator creates a transaction that:
    *   Spends the current state UTXO.
    *   Includes the `UpdateRoot` redeemer with the `new_root`.
    *   Includes an output back to the script address containing the new `RegistryState` datum (with the `new_root`) and preserving the locked value.
    *   Is signed by the curator key.
4.  **Off-Chain Verification:** Users/applications query the current state UTXO at the script address to get the latest `merkle_root`. They can then verify if a specific issuer is part of the registry using the issuer's data and a Merkle proof provided by an off-chain service, checking it against the on-chain `merkle_root`.

## Security Considerations

*   The integrity of the registry relies entirely on the security of the curator's private key (`curator_pkh`). Compromise of this key allows arbitrary changes to the Merkle root.
*   Ensure the `curator_pkh` parameter is set correctly during blueprint generation.
*   The security and correctness of off-chain Merkle proof generation and verification are crucial for the overall system's reliability. 

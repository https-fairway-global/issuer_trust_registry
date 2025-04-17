# Trust Registry Smart Contract (fairway/trust_registry)

This Aiken project implements an on-chain trust registry, acting as a simple vault managed by a designated administrator. It allows storing and managing information about trusted issuers, specifically their Decentralized Identifiers (DIDs), names, and the types of credentials they are authorized to issue.

## Contract Overview

The contract uses a state-per-UTXO pattern, where each UTXO locked at the script address represents a single registered issuer.

### Parameters

The validator is parameterized at compile time with the administrator's public key hash:

*   `admin_pkh: VerificationKeyHash`: The hash of the verification key belonging to the administrator authorized to manage registry entries.

### Datum (`RegistryEntry`)

Each UTXO representing an entry in the registry holds the following datum:

*   `issuer_did: ByteArray`: The unique Decentralized Identifier (DID) of the registered issuer.
*   `issuer_name: ByteArray`: A human-readable name for the issuer (UTF-8 encoded).
*   `credential_types: List<ByteArray>`: A list of identifiers or names representing the types of credentials this issuer is authorized to issue.

### Redeemer (`Action`)

To modify or remove an existing registry entry, the administrator must submit a transaction that spends the corresponding UTXO, providing one of the following redeemers:

*   `UpdateEntry { name: ByteArray, cred_types: List<ByteArray> }`: Used to update the `issuer_name` and `credential_types` for an existing entry. The `issuer_did` remains unchanged.
*   `RemoveEntry`: Used to permanently remove an issuer's entry from the registry.

### Logic (`spend` handler)

The core logic resides in the `spend` handler, which validates attempts to spend existing registry entry UTxOs:

1.  **Admin Signature:** The transaction *must* be signed by the key corresponding to the `admin_pkh` parameter.
2.  **Datum Presence:** The UTXO being spent *must* contain a valid `RegistryEntry` datum.
3.  **Action Dispatch:** The logic branches based on the provided `Action` redeemer:
    *   **On `UpdateEntry`:**
        *   Ensures exactly one output is sent back to the script address.
        *   Verifies the output datum contains the *same* `issuer_did` as the input.
        *   Verifies the output datum's `issuer_name` and `credential_types` match those provided in the redeemer.
        *   Ensures the Ada value (and any other tokens) in the output is greater than or equal to the input value (value preservation).
    *   **On `RemoveEntry`:**
        *   Ensures *no* output is sent back to the script address, effectively consuming and deleting the entry.

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

1.  **Instantiation:** Build the contract (`aiken build`) and apply the `admin_pkh` parameter to the generated blueprint to get the script address.
2.  **Creating Entries:** Send a transaction locking a UTXO (e.g., containing minimum Ada) at the script address. The transaction must include the `RegistryEntry` datum (inline) for the issuer being registered.
3.  **Updating Entries:** The administrator creates a transaction that:
    *   Spends the UTXO of the entry to be updated.
    *   Includes the `UpdateEntry` redeemer with the new name and credential types.
    *   Includes an output back to the script address containing the updated `RegistryEntry` datum and preserving the locked value.
    *   Is signed by the admin key.
4.  **Removing Entries:** The administrator creates a transaction that:
    *   Spends the UTXO of the entry to be removed.
    *   Includes the `RemoveEntry` redeemer.
    *   Does *not* include any output back to the script address.
    *   Is signed by the admin key.

## Security Considerations

*   The security of the registry relies entirely on the security of the administrator's private key (`admin_pkh`). Compromise of this key allows full control over all registry entries.
*   Ensure the `admin_pkh` parameter is set correctly during blueprint generation. 
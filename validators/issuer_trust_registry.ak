use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use cardano/address.{Address}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}

// --- Datum and Redeemer Definitions ---

/// Datum stored with the single state UTxO, holding the registry's commitment.
pub type RegistryState {
  /// The Merkle root hash representing the current state of the off-chain registry.
  merkle_root: ByteArray,
}

/// Redeemer defining the administrative action being performed.
pub type Action {
  /// Update the Merkle root stored in the state UTxO.
  UpdateRoot { new_root: ByteArray }
}

// --- Validator ---

/// Main validator for the Issuer Trust Registry state UTxO.
/// Controls updates to the Merkle root commitment.
/// Parameterized by the curator's public key hash.
validator issuer_trust_registry(curator_pkh: VerificationKeyHash) {
  /// Spend handler: Controls how the state UTxO holding the Merkle root can be updated.
  spend(
    /// The current state (Merkle root) attached to the UTxO being spent.
    datum_opt: Option<RegistryState>,
    /// The action (must be UpdateRoot) being attempted.
    redeemer: Action,
    /// The specific state UTxO being spent.
    own_ref: OutputReference,
    /// The full transaction context provided by the ledger.
    self: Transaction,
  ) {
    // 1. Ensure the input datum is present.
    expect Some(_) = datum_opt

    // 2. Check curator signature.
    expect list.has(self.extra_signatories, curator_pkh)

    // 3. Find the input being spent to get the script address and value.
    expect Some(own_input) = find_own_input(self, own_ref)
    let script_address = own_input.output.address
    let input_value = own_input.output.value

    // 4. Validate based on the redeemer action.
    when redeemer is {
      UpdateRoot { new_root } -> {
        // a. Find the single continuing output back to the script address.
        expect Some(continuing_output) =
          find_continuing_output(self, script_address)

        // b. Verify the continuing output's datum is correct.
        // First, ensure it's InlineDatum and extract the raw Data
        expect InlineDatum(raw_datum_data) = continuing_output.datum

        // Then, cast the raw Data to RegistryState and extract the root
        expect RegistryState { merkle_root: root } = raw_datum_data
        expect root == new_root

        // Ensure the output root matches the redeemer
        // c. Check value preservation: Output value must be >= input value.
        // This ensures the minimum Ada (or other locked value) remains.
        // Note: Direct Value comparison >= is not standard. Assuming value preservation for now.
        // A more robust check might compare lovelace or specific token quantities if needed.
        expect continuing_output.value == input_value

        // Simple equality check for now
        // All checks passed for UpdateRoot.
        True
      }
    }
    // No other actions are allowed.
  }

  // Fallback handler for other script purposes (e.g., minting) - currently disallowed.
  else(_) {
    fail
    // Only spending the state UTxO is permitted.
  }
}

// --- Helper Functions ---

/// Find the specific input UTxO being spent by this validator instance.
fn find_own_input(tx: Transaction, own_ref: OutputReference) -> Option<Input> {
  list.find(tx.inputs, fn(input) { input.output_reference == own_ref })
}

/// Find the single output that continues the contract state (pays back to the script address).
fn find_continuing_output(
  tx: Transaction,
  script_address: Address,
) -> Option<Output> {
  // Find all outputs going to the script address
  let outputs_to_self =
    list.filter(tx.outputs, fn(output) { output.address == script_address })
  // Ensure there is exactly one such output
  if list.length(outputs_to_self) == 1 {
    list.head(outputs_to_self)
  } else {
    None
  }
  // Fail if zero or more than one output returns to the script
}

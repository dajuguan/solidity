import ckzg
import hashlib

###############################################################################
# Constants
###############################################################################
MODULUS_BLS = 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001
RU_BLS = 0x564c0a11a0f704f4fc3e8acfe0f8245f0ad1347b378fbf96e206da11a5d36306 # root of unity
FIELD_ELEMENTS_PER_BLOB = 4096
BYTES_PER_FIELD_ELEMENT = 32
VERSIONED_HASH_VERSION_KZG = "01"

###############################################################################
# Helper Functions
###############################################################################

def bytes_from_hex(hexstring):
    return bytes.fromhex(hexstring.replace("0x", ""))

# generate a blob with 4096 field elements with value ranging from 0-4096
def gen_bytes():
    # FIELD_ELEMENTS_PER_BLOB * BYTES_PER_FIELD_ELEMENT
    res = bytearray()
    for i in range(0,FIELD_ELEMENTS_PER_BLOB):
        bytes_i = (i).to_bytes(BYTES_PER_FIELD_ELEMENT, byteorder='big',signed=False)
        res.extend(bytes_i)
    return bytes(res)

def reverse_bits(n: int, order: int) -> int:
    """
    Reverse the bit order of an integer ``n``.
    """
    # Convert n to binary with the same number of bits as "order" - 1, then reverse its bit order
    return int(('{:0' + str(order.bit_length() - 1) + 'b}').format(n)[::-1], 2)

# @param idx: the index of blob in bytes32 array
# @return z: evaluation point of the blob polynomial
def z_at_blob_idx(idx):
    idx_rev = reverse_bits(idx, FIELD_ELEMENTS_PER_BLOB)
    ru_idx_rev = (RU_BLS ** idx_rev) % MODULUS_BLS
    z = ru_idx_rev.to_bytes(BYTES_PER_FIELD_ELEMENT, byteorder='big',signed=False)
    return z

# @param commitment: bytes
def kzg_to_versioned_hash(commitment):
    k = hashlib.sha256()
    k.update(commitment)
    return VERSIONED_HASH_VERSION_KZG + k.hexdigest()[2:]

###############################################################################
# Tests
###############################################################################

def test_blob_to_kzg_commitment(ts):
    blob = gen_bytes()
    commitment = ckzg.blob_to_kzg_commitment(blob, ts)
    print("expected commitment:", commitment.hex())
    return commitment

def test_blob_to_versioned_hash(ts):
    blob = gen_bytes()
    commitment = ckzg.blob_to_kzg_commitment(blob, ts)
    versioned_hash = kzg_to_versioned_hash(commitment)
    print("expected versioned_hash:", versioned_hash)
    return versioned_hash

def test_compute_kzg_proof(ts, idx):
    blob = gen_bytes()
    z = z_at_blob_idx(idx)
    print("z hex:", z.hex())
    proof, y = ckzg.compute_kzg_proof(blob, z, ts)
    print("expected proof:", proof.hex())
    print("expected y", y.hex(), int.from_bytes(y, "big"))
    assert int.from_bytes(y, "big") == idx
    return (z, proof, y)


def test_verify_kzg_proof(ts, idx):
    commitment = test_blob_to_kzg_commitment(ts)
    (z, proof, y) = test_compute_kzg_proof(ts, idx)
    valid = ckzg.verify_kzg_proof(commitment, z, y, proof, ts)
    assert valid

###############################################################################
# Main Logic
###############################################################################

if __name__ == "__main__":
    ts = ckzg.load_trusted_setup("./trusted_setup.txt")

    test_blob_to_kzg_commitment(ts)
    test_blob_to_versioned_hash(ts)
    test_compute_kzg_proof(ts,  1)
    # test_verify_kzg_proof(ts, 102)
    print("tests passed")
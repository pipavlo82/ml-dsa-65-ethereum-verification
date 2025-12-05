// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";

contract MLDSA_RealVector_Test is Test {
    using stdJson for string;

    string constant VEC_PATH = "test_vectors/vector_001.json";

    function test_real_vector() public {
        string memory json = vm.readFile(VEC_PATH);

        string memory msgHashHex = json.readString(".msg_hash");
        string memory sigB64     = json.readString(".sig_pq_b64");
        string memory pkB64      = json.readString(".pq_pubkey_b64");
        string memory scheme     = json.readString(".pq_scheme");

        bytes32 msgHash = _parseHex32(msgHashHex);
        bytes memory sig = Base64Decode.decode(sigB64);
        bytes memory pk  = Base64Decode.decode(pkB64);

        emit log_bytes32(msgHash);
        emit log_uint(sig.length);
        emit log_uint(pk.length);

        assertEq(keccak256(bytes(scheme)), keccak256(bytes("ML-DSA-65")));
        assertEq(pk.length, 1952, "ML-DSA-65 public key length mismatch");
        assertEq(sig.length, 3309, "ML-DSA-65 signature length mismatch");
    }

    function _parseHex32(string memory s) internal pure returns (bytes32 r) {
        bytes memory b = bytes(s);
        require(b.length == 66 && b[0] == "0" && (b[1] == "x" || b[1] == "X"), "bad hex32");

        uint256 acc = 0;
        for (uint256 i = 2; i < 66; i++) {
            acc = (acc << 4) | _fromHexChar(uint8(b[i]));
        }
        r = bytes32(acc);
    }

    function _fromHexChar(uint8 c) private pure returns (uint8) {
        if (c >= "0" && c <= "9") return c - uint8(bytes1("0"));
        if (c >= "a" && c <= "f") return 10 + c - uint8(bytes1("a"));
        if (c >= "A" && c <= "F") return 10 + c - uint8(bytes1("A"));
        revert("invalid hex");
    }
}

library Base64Decode {
    bytes constant TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    function decode(string memory _data) internal pure returns (bytes memory) {
        bytes memory data = bytes(_data);
        require(data.length % 4 == 0, "invalid b64");

        uint256 padding = 0;
        if (data[data.length - 1] == "=") padding++;
        if (data[data.length - 2] == "=") padding++;

        uint256 outLen = (data.length / 4) * 3 - padding;
        bytes memory result = new bytes(outLen);

        uint256 j = 0;
        for (uint256 i = 0; i < data.length; i += 4) {
            uint256 n =
                (_decodeChar(uint8(data[i])) << 18) |
                (_decodeChar(uint8(data[i+1])) << 12) |
                (_decodeChar(uint8(data[i+2])) << 6) |
                (_decodeChar(uint8(data[i+3])));

            result[j++] = bytes1(uint8((n >> 16) & 0xFF));
            if (j < outLen) result[j++] = bytes1(uint8((n >> 8) & 0xFF));
            if (j < outLen) result[j++] = bytes1(uint8(n & 0xFF));
        }

        return result;
    }

    function _decodeChar(uint8 c) private pure returns (uint8) {
        if (c == "=") return 0;
        for (uint256 i = 0; i < 64; i++) {
            if (TABLE[i] == bytes1(c)) return uint8(i);
        }
        revert("invalid b64 char");
    }
}

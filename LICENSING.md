# Licensing scope

The Apache License, Version 2.0, reproduced in [LICENSE](LICENSE), applies to
Pavlo-authored repository material within the scope below, to the extent Pavlo
owns or is authorized to license the relevant rights.

Copyright 2026 Pavlo Tvardovskyi

Existing third-party copyright, license, patent, attribution and trademark
notices remain applicable. For mixed or adapted material, the new grant covers
only Pavlo's original additions. Imported source, external contributions,
quoted specifications, captures and other third-party material are not
relicensed by this grant. Inclusion in this repository or a missing license
does not itself supply permission. Existing grants are not withdrawn or narrowed.

| Material present on the reviewed default-branch base | Applicable boundary |
| --- | --- |
| Pavlo-authored `contracts/**`, `solidity/**`, `test/**`, `scripts/**`, `research/**`, original specifications/docs and repository configuration | Apache-2.0 for Pavlo's original contributions. Existing MIT source-header grants remain available and are not withdrawn. |
| `lib/forge-std` | Pinned separate submodule with its original terms. The gitlink, `.gitmodules`, `foundry.lock` and existing source notices are unchanged; the submodule was not fetched for this task. |
| `test_vectors/*.json` | Preserved generated/imported cryptographic operands and reference outputs. This root grant does not establish the authorship or licensing completeness of every underlying operand. Existing source rights and provenance apply; no vector bytes or provenance are rewritten. |
| Dependency/backend source referenced by the signing/conversion tools | Dependencies are separate works governed by their own terms. Only Pavlo's original wrapper code is covered by this new grant. |

README references to vendored Keccak/SHAKE code or advanced verification describe
other work/state and do not establish that those files exist in this reviewed
default-branch tree. This licensing PR does not import unmerged code, relicense a
vendor, change verification behavior, or claim cryptographic completeness.
Existing MIT permissions are preserved alongside this current Apache grant for
Pavlo-authored material. All vectors, source headers and technical pins remain
unchanged.

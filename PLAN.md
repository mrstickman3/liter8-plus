# Plan: Expand A12/A13 Support and Fix Project Issues

## Goal
Add support for all A12/A13 devices and resolve as many "What doesn't" items as possible to improve the project's overall quality and utility.

## Acceptance Criteria
1. **Hardware Support:** `DeviceWorkflowRegistry` includes all A12/A13 device classes (e.g., iPhone XS, XS Max, XR, 11, 11 Pro, 11 Pro Max).
2. **README Update:** `README.md` accurately reflects the expanded support and updated status of known issues.
3. **Cellular Improvements:** Ensure `l8fdr.dylib` and `CommCenter` activation patches are applied by default for all supported boards.
4. **Injection Stability:** Improvements made to `launchdhook` to increase stability relative to vphone.
5. **Verification:** All changes pass `make check` and existing tests.

## Implementation Approach

### Phase 1: Expand Hardware Support
1. **Device Mapping:** Research and list all A12/A13 device identifiers (DeviceClass, ChipID, BoardID).
2. **Profile Expansion:** Add `DeviceWorkflowProfile` entries to `Sources/Liter8Core/Firmware/IPSWManifest.swift` for these devices. 
   - *Note:* For devices without measured guards (launchd SHA, etc.), they will be marked as `.experimental`.
3. **Boot Plan Generalization:** Ensure `DeviceBootPlan` correctly distinguishes between `n104ap` (iPhone 11) and others (e.g., avoiding the `skipDisplayInitialization` if not needed).

### Phase 2: Address "What Doesn't"
1. **Cellular/VoLTE:**
   - Verify `CommCenterDataActivationResolver` covers all A12/A13 kernel variants.
   - Ensure `l8fdr.dylib` is deployed across all target boards in `sshrd_provision.sh`.
2. **Injection Stability (`device/launchdhook`):**
   - Compare `lhook.c` logic with known stable injection patterns (like vphone).
   - Focus on `posix_spawn` interposition stability and memory ownership.
3. **MobileBackup2 / Persona State:**
   - Identified as a Hard SEP Gate; marked as a known limitation in documentation.

### Phase 3: Documentation & Cleanup
1. **README.md:** Update the "Builds and devices" table.
2. **What doesn't:** Update the list based on fixes applied.

## Verification Contract
- **Build:** `make release`
- **Tests:** `make check` (includes `test-full`, `test-e2e`, and `integration`)
- **Manual Check:** Verify `README.md` and `IPSWManifest.swift` for consistency.

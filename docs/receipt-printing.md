# Receipt printing implementation

## Scope and design

- Business app only: owners and managers configure printers inside Business Settings.
- Printer configuration is stored on this device, scoped to the account and salon, and is never included in cloud workspace snapshots.
- Receipt previews and checkout receipts offer Print receipt. They use the saved configuration; setup is available only through Business Settings.
- Support common ESC/POS thermal printers over Bluetooth Classic, BLE, network TCP and Android USB, plus regular printers through Android's system print dialog.
- Thermal setup includes paper width (58/80 mm), printable dots, connection details, cutter option and a test receipt. Network setup accepts a host and port rather than relying on unreliable discovery.
- System printing produces an A4 PDF and delegates printer selection to Android's installed print services. Android owns its printer defaults.
- Generate both outputs from saved Bill amounts; never recalculate or resave the sale when printing.
- Keep plugin calls behind repository contracts/use cases and Provider state. Share one print controller across the business workspace so parallel receipt screens cannot submit overlapping jobs.
- Handle permission refusal, connection failure, timeout and cancellation. Do not silently retry a receipt after an ambiguous send; show that it may already have printed.
- Bluetooth and USB permissions belong to the business flavor only. No database changes are required.

## Implementation sequence

1. Inspect and pin compatible printing dependencies and their native Android setup.
2. Add printer models, local preferences, receipt encoders and hardware/system adapters.
3. Add Business Settings printer setup and test-print controls.
4. Add Print receipt to receipt preview and checkout receipt dialogs.
5. Verify settings isolation, bill rendering, failure/duplicate handling, layout and existing business flows with automated checks.
6. Document verification and physical-printer checks. Android compilation was stopped at the user's request; do not restart it as part of this task.

## Using the feature

Open the business workspace menu, then **Business Settings → Receipt printer**.
Choose **Regular printer (Android print dialog)** for office printers, or choose
the thermal connection type. Save the configuration, then use **Print test receipt**.
Thermal printers connect when a receipt is sent and disconnect after transmission;
the saved-printer label is configuration status, not a claim that the device is connected.
For Bluetooth/USB, select a discovered device. For network printers, enter the host
and port. Save changes before testing them. Use **Remove saved printer** to reset.

Checkout's saved-receipt dialog and the full Receipt screen both offer **Print receipt**.
The mobile bill-details screen opens that full preview through **Receipt**.
Unconfigured printing directs the user to Business Settings; printer configuration
is not exposed on receipt or customer screens. Existing receipt sharing remains available.

## Pinned packages

- `unified_esc_pos_printer` 3.4.0: Bluetooth Classic/BLE, network TCP, USB and ESC/POS generation.
- `printing` 5.14.3 and `pdf` 3.12.0: Android print dialog and A4 output.
- `image` 4.8.0: receipt bitmap encoding compatible with the PDF package's archive range.
- `permission_handler` 13.0.2: opening Android app permissions after refusal; printer transport requests the relevant Bluetooth/USB permissions itself.
- `network_info_plus` 7.0.0: constrain the thermal package's transitive dependency to the repository's existing `win32` 5 override. Network printer setup uses a manual host, without subnet discovery.
- `libserialport_plus` 0.1.1: constrain the optional desktop transport to its Flutter-plugin release so Windows widget tests do not require a C compiler. Android USB uses `usb_serial` or the package's native printer-class adapter.

Newer PDF/printing releases require a newer Dart SDK than this project's Dart 3.10.3.
The initial `thermal_printer_plus` candidate was not retained: its USB/BLE write
handling was insufficient for reliable long jobs. No edits to the global package cache are required.

## Compatibility boundary

Connection type alone does not establish printer compatibility. Direct thermal printing requires ESC/POS support and a compatible transport. Proprietary printers need a vendor adapter. USB requires USB-host/OTG support. System printing requires an installed Android print service that supports the selected printer. Printer status and paper/cutter capabilities vary by model.

## Physical acceptance checks

- Pair and test a Bluetooth Classic printer; deny and then grant Nearby devices permission.
- Test a compatible BLE printer, including a long receipt.
- Print over the same LAN by host/IP and port; test an unreachable printer.
- Test a USB ESC/POS printer with an OTG/USB-host device and Android's device permission prompt.
- Check 58 mm and 80 mm output, long service names, totals, discounts, tax, logo and multilingual text.
- Open the system print dialog, cancel it, save as PDF and print through a supported print service.
- Verify owner and manager settings isolation and persistence after app restart.
- Verify receipt reprinting does not create a new sale and failed/ambiguous sends never automatically reprint.

## Verification results

- Focused regression run: 27 tests passed across printing, business Home/settings navigation, manager entry, bill totals and business logo picking (`build/printer-checks.log`).
- Network integration test: a local TCP listener received the complete 32 KB payload, including transport initialization; connection refusal and subsequent lock release are covered.
- System-print adapter tests cover submission, cancellation and overlapping calls from separate workspaces. Native Android print services are not simulated as physical printers.
- Settings flows cover 320, 390 and 1024 pixel widths, with existing Home navigation covered at 320, 390 and 1280 widths.
- Thermal output is rasterized using Flutter text shaping for multilingual text, keeping logo/text output independent of printer code pages. An 80-line receipt successfully generated a multipage PDF. Receipt bitmap and settings screenshots are in `build/printer-review/`.
- Final verification after the cross-workspace discovery guard: all 15 printing tests passed (`build/printer-final.log`); `flutter analyze --no-pub` reported no issues; Git whitespace checks passed with this Windows repository's CRLF convention.
- An earlier full-suite run was interrupted and is not a passing verification result; it included photo/screenshot failures. The focused logo regression subsequently passed. No unrelated photo-test changes were made.
- Android APK compilation was **not verified**. The wrapper stalled downloading Gradle 8.12; an installed Gradle 8.14 invocation reached project configuration before the user requested that Android builds stop. Both build invocations were stopped. No build-tool configuration was changed.
- Physical printing cannot be certified without target hardware: Bluetooth/USB permission prompts, real print services, paper feed/cutting, print quality and manufacturer compatibility remain device acceptance checks.

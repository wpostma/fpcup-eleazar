# fpcupdeluxe — CLAUDE.md

## What This Project Is

fpcupdeluxe is a GUI (and CLI) installer/updater for **Free Pascal Compiler (FPC)** and the **Lazarus IDE**. It automates downloading source code from git/SVN/Mercurial repos, running `make` and `fpc` to compile them, setting up cross-compilers, and managing multiple FPC/Lazarus installations.

Built with **Free Pascal + Lazarus LCL** (the Open Source Delphi-compatible IDE). Target platforms: Windows (primary), Linux, macOS. This working copy lives at `C:\FPC\fpcupdeluxe`.

---

## Source Tree Layout

```
C:\FPC\fpcupdeluxe\
|-- fpcupdeluxe.lpi          <- Main Lazarus project file (build this)
|-- up.lpr                   <- GUI program entry point (fpcupdeluxe.exe)
|-- fpcup.lpr                <- CLI-only entry point (fpcup.exe, no LCL)
|-- build.ps1                <- PowerShell build script (wraps lazbuild)
|-- build.sh                 <- Linux/macOS build script
|-- sources/
|   |-- updeluxe/
|   |   |-- fpcupdeluxemainform.pas  <- Main GUI form (~4700 lines) PRIMARY FILE
|   |   |-- fpcupdeluxemainform.lfm  <- Form layout (component tree)
|   |   `-- backup/                  <- Backup copies of main form files
|   |-- up/
|   |   |-- checkoptions.pas         <- CLI argument parsing
|   |   `-- fpcuplprbase.inc         <- Shared LPR base include
|   |-- installermanager.pas    <- TFPCupManager + TSequencer (orchestration)
|   |-- installercore.pas       <- TInstaller abstract base (~158 KB, huge)
|   |-- installerfpc.pas        <- FPC compiler installation steps
|   |-- installerlazarus.pas    <- Lazarus IDE installation steps
|   |-- installeruniversal.pas  <- Universal/cross-compiler modules + URL aliases
|   |-- installerhelp.pas       <- FPC/Lazarus help installation
|   |-- installerbase.pas       <- Type defs: TOS, TCPU enums; error flag sets
|   |-- processutils.pas        <- TExternalTool, TExternalToolThread (process exec)
|   |-- fpcuputil.pas           <- General utilities
|   |-- fpcupdefines.inc        <- Compiler defines ({$define READER} etc.)
|   |-- repoclient.pas          <- Abstract VCS client base
|   |-- gitclient.pas           <- Git VCS client
|   |-- svnclient.pas           <- SVN VCS client
|   |-- hgclient.pas            <- Mercurial VCS client
|   |-- m_crossinstaller.pas    <- Cross-compiler installer base class
|   |-- crossinstallers/        <- Per-target cross-compiler modules (m_any_to_*.pas)
|   `-- commandline.pas         <- CLI argument processing
|-- sources/updeluxe/readerstub/
|   `-- fpcupdeluxemainformreader.pas  <- Thin wrapper for READER build mode
`-- buildlibs/                  <- Compiled output (.ppu, .o, .exe per platform)
```

---

## Architecture: Call Stack for Install Operations

```
TForm1.InstallClick (button handler in mainform)
  `- TForm1.PrepareRun     validates inputs, sets FPCupManager config
       `- TForm1.RealRun   sets FRunning=true, calls FPCupManager.Run
            `- TFPCupManager.Run (installermanager.pas)
                 `- TSequencer.Run (state machine loop over module list)
                      `- TInstaller.ExecuteXxx (installerfpc/lazarus/universal.pas)
                           `- TInstaller.Processor.Execute (processutils.pas)
                                `- TExternalTool  spawns OS process (git, make, fpc, lazbuild)
                                     `- TExternalTool.WaitForExit (line 874)
                                          `- Application.ProcessMessages (keeps GUI alive)
```

**The entire sequence runs synchronously on the main thread.** The GUI stays responsive only because `WaitForExit` calls `Application.ProcessMessages` in a busy-wait loop. There is no background thread for the build — all installer logic blocks the main thread between ProcessMessages calls.

---

## Key Classes

### TForm1 — `sources/updeluxe/fpcupdeluxemainform.pas`

The main window. Form class is `TForm1` (Lazarus default name, not renamed).

Critical private fields (declared ~line 233):

| Field | Type | Purpose |
|-------|------|---------|
| `FPCupManager` | `TFPCupManager` | Central manager; created at startup, owned by form |
| `FRunning` | `boolean` | True while RealRun is on the call stack |
| `FCloseRequested` | `boolean` | Set by FormClose when FRunning=true; triggers deferred close |
| `sInstallDir` | `string` | User-selected installation root directory |
| `MissingCrossBins` | `boolean` | Error flag: cross binary tools missing after last run |
| `MissingCrossLibs` | `boolean` | Error flag: cross libraries missing after last run |
| `MissingTools` | `boolean` | Error flag: system tools missing |

Key procedures:
- `InstallClick` — all install buttons route here (line ~3400)
- `PrepareRun(Sender)` — validates inputs, configures FPCupManager (line ~4244)
- `RealRun(Sender)` — sets FRunning=true, calls FPCupManager.Run, clears FRunning (line ~4460)
- `BitBtnHaltClick` — Stop button handler (line 1552)
- `FormClose` — defers close if FRunning; saves settings and destroys FPCupManager otherwise (line 4155)
- `FormDestroy` — final cleanup including StrDispose loops for listbox items (line ~4100)
- `DisEnable(Sender, value)` — enables/disables all controls except BitBtnHalt and output (line 4211)
- `AddMessage(s)` — appends text to the SynEdit output log
- `GetFPCUPSettings(dir)` / `SetFPCUPSettings(dir)` — INI settings load/save

The form has two conditional variants via `{$ifdef READER}`:
- **Normal mode**: `BitBtnHalt` is `TBitBtn` with icon; uses `TSynEdit` for output
- **READER mode**: `BitBtnHalt` is plain `TButton`; uses `TMemo` for output

### TFPCupManager — `sources/installermanager.pas:166`

Central orchestrator. Holds all user configuration: paths, URLs, version branch/tag targets, proxy settings, module lists, cross-compiler targets (TOS/TCPU), option strings (fpcOPT, lazOPT, etc.).

Key property: `Sequencer: TSequencer` — the state machine that drives execution.
Key method: `Run: boolean` — starts the state machine; returns true on success.
Key property: `RunInfo: string` — human-readable description of last run result.
Key property: `InstallerErrors: TInstallerErrors` — set of error flags (ieBins, ieLibs, ieTarget).

### TSequencer — `sources/installermanager.pas:423`

State machine over the module list. Each module (entry in `FParent.FModuleList`) has a `TSequenceAttributes` record tracking its execution state:

- `ESNever` — not yet run
- `ESFailed` — failed or killed
- `ESSucceeded` — completed successfully

Key methods:
- `Run` — main execution loop; calls each module's installer in sequence
- `Kill` (line 3211) — Stop button target; terminates current process + marks all ESFailed
- `ResetAllExecuted` — resets entire state machine for retry

`Kill` implementation:
1. If `Installer` and `Installer.Processor` are assigned: calls `Processor.Terminate`
2. Iterates all modules: sets `Executed := ESFailed`
3. Sets `FParent.RunInfo := 'Process forcefully interrupted by user.'`

### TInstaller — `sources/installercore.pas:392`

Abstract base for all installer types (FPC, Lazarus, Help, Universal cross-compilers).
Key property: `Processor: TExternalTool` — executes external commands (git, make, fpc, etc.)

Subclasses:
- `TFPCInstaller` — installercore.pas (FPC bootstrap/compile/install)
- `TFPCNativeInstaller` — installerfpc.pas
- `TLazarusNativeInstaller` — installerlazarus.pas
- `TUniversalInstaller` — installeruniversal.pas (extra modules, OPM, etc.)

### TExternalTool — `sources/processutils.pas:179`

Wraps `TProcess` for spawning and managing external commands.

Key methods:
- `Execute` — validates stage, calls DoStart to spawn the process
- `WaitForExit` (line 874) — busy-waits with `Application.ProcessMessages` until stopped
- `Terminate` (line 869) — calls `DoTerminate`
- `DoTerminate` (~line 790) — sets stage to etsWaitingForStop, calls `Process.Terminate(AbortedExitCode)` + `Process.WaitOnExit(5000)`

Stage enum: `etsWaitingForStart`, `etsStarting`, `etsRunning`, `etsWaitingForStop`, `etsStopped`, `etsDestroying`

Optional: `TExternalToolThread` (line 157) — thread that reads process stdout/stderr and filters output. Not always used; the form uses a callback (`ProcessInfo`) for real-time output via `WM_THREADINFO` message.

---

## Stop / Cancel Button Mechanism

**Button:** `BitBtnHalt` (TBitBtn in normal mode, TButton in READER mode)
**Handler:** `TForm1.BitBtnHaltClick` (`fpcupdeluxemainform.pas:1552`)

Current flow when user clicks Stop:

1. `MessageDlgEx` shows "I am going to try to halt..." with Yes/No (modal dialog)
2. If user clicks No: exits immediately
3. Sets `StatusMessage.Text := 'Stopped/Aborted'`
4. If `FPCupManager` and `FPCupManager.Sequencer` are assigned: calls `Sequencer.Kill`

`Kill` (installermanager.pas:3211) then:
1. Calls `Installer.Processor.Terminate` — which calls `Process.Terminate(AbortedExitCode)` and waits up to 5 seconds for it to exit
2. Marks all module sequence states as `ESFailed` — sequencer loop exits on next iteration
3. Sets `RunInfo := 'Process forcefully interrupted by user.'`

After Kill returns, the `WaitForExit` loop in processutils sees `Stage = etsStopped` and breaks. Control unwinds through TInstaller → TSequencer.Run → TFPCupManager.Run → back to `TForm1.RealRun`, which then disables BitBtnHalt, sets `FRunning := false`, and (if `FCloseRequested`) calls `Close`.

**FormClose safety** (added in commit 38709f20): If `FRunning` is true when the user
tries to close the window, `FormClose` calls `Sequencer.Kill`, sets `FCloseRequested := true`,
sets `CloseAction := caNone` (prevents immediate close), and exits. When `RealRun` eventually
exits normally, it calls `Close` which re-enters `FormClose` with `FRunning = false` and
completes the normal save-and-destroy path.

---

## Conditional Compilation Defines

| Define | Set in | Effect |
|--------|--------|--------|
| `READER` | Build mode `.lpi` | Strips SynEdit; uses TMemo + plain TButton; lite variant |
| `RemoteLog` | fpcupdefines.inc | Enables mORMot-based telemetry; adds `aDataClient` field |
| `EnableLanguages` | fpcupdefines.inc | Enables LCL translation / multi-language support |
| `FPCONLY` | fpcup.lpi | CLI mode: builds FPC only, no Lazarus; used for fpcup.lpr |
| `LCL` | Lazarus always sets this | Activates GUI form units; {$ifdef LCL} guards GUI code |
| `DEBUG` | Debug build mode | Enables debug output, assertions |

Build modes in `fpcupdeluxe.lpi`: `Default`, `win32`, `win64`, `Debug`, `READER` etc.

---

## Building the Project

**Requires:** An existing Lazarus+FPC installation (the "bootstrap" compiler).
`build.ps1` defaults point to `C:\FPC\fpcup_trunk`.

```powershell
# Default build (win32 mode, uses fpcup_trunk bootstrap):
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\FPC\fpcupdeluxe\build.ps1"

# Explicit parameters:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\FPC\fpcupdeluxe\build.ps1" `
    -BuildMode win64 `
    -LazBuild "C:\FPC\fpcup_trunk\lazarus\lazbuild.exe" `
    -FpcDir   "C:\FPC\fpcup_trunk\fpc\bin\x86_64-win64"
```

`lazbuild` reads `fpcupdeluxe.lpi`, resolves all package dependencies (LCL, SynEdit, etc.), and invokes `fpc.exe` internally.

The GUI entry point is `up.lpr` (compiled to `fpcupdeluxe.exe`).
The CLI entry point is `fpcup.lpr` (compiled to `fpcup.exe`, no LCL dependency).

---

## Recent History (Stop Button)

- **f47410fe**: UI refactoring introduced a crash when the user clicked Stop while a
  build was running. The confirmation dialog (`MessageDlgEx`) pumped the message queue;
  a WM_CLOSE message dispatched during that loop hit `FormClose` while `FPCupManager.Run`
  was still on the call stack, causing a use-after-free when FormClose destroyed FPCupManager.

- **38709f20** (Apr 22 2026): Fixed the crash by adding `FRunning`/`FCloseRequested` flags
  so FormClose defers destruction safely. Also guarded `BitBtnHaltClick` against nil
  FPCupManager, and fixed StrDispose memory leaks in FormDestroy.

**Current status of Stop:** The button works structurally — Kill is called, the external
process is terminated, the sequencer halts. The confirmation dialog ("Do not expect too
much of it") remains as a user warning. The process termination path is:
  BitBtnHaltClick -> Sequencer.Kill -> Processor.Terminate -> Process.Terminate(AbortedExitCode)

---

## File Conventions

- All `.pas` / `.lfm` / `.lpi` / `.inc` files: **CRLF** line endings (Windows Lazarus requirement)
- After every Write/Edit of `.pas`, `.lfm`, `.lpi`, `.inc`: run `unix2dos <path>` and verify with `file <path>`
- Free Pascal style: `{$mode objfpc}{$H+}`, AnsiString by default, `begin`/`end` blocks
- Published component fields declared at top of `TForm1` class must match `.lfm` component names exactly (Lazarus deserializes by name at runtime)
- `TForm1` is the main form class (Lazarus default, not renamed)
- Component naming convention: `BitBtnXxx` for TBitBtn install buttons, `btnXxx` for TButton utility buttons

---

## What the App Does (User Perspective)

1. User picks FPC version (stable / trunk / fixes branch / specific tag) and Lazarus version
2. User picks install directory
3. User clicks one of: **Install FPC+Lazarus**, **FPC only**, **Lazarus only**, or a cross-compiler button
4. The app:
   - Fetches FPC/Lazarus source via git (or SVN fallback)
   - Runs `make bootstrap` to build a bootstrap FPC from the bootstrap binary
   - Compiles FPC from source using the bootstrap compiler
   - Compiles Lazarus (lazbuild + full IDE) using the newly compiled FPC
   - Sets up configuration paths, creates desktop shortcut
5. The Stop button (`BitBtnHalt`) lets the user abort mid-operation by killing the
   currently running external process (git, make, fpc, lazbuild) and halting the sequencer

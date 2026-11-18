# Graphitree

A native macOS app to see, sort out and clean up [graphify](https://github.com/Graphify-Labs/graphify) knowledge graphs.

Built on [graphify](https://github.com/Graphify-Labs/graphify) by Graphify Labs, and installed with [uv](https://github.com/astral-sh/uv) by Astral. Please support them. See [Credits](#credits).

## Install

Graphitree runs on macOS 15 or later, on Apple silicon or Intel. It shows the knowledge graphs [graphify](https://github.com/Graphify-Labs/graphify) makes of your code, and it installs graphify for you if you don't have it.

### Download

1. Download `Graphitree-<version>.dmg` from the [latest release](https://github.com/MarcusLai07/graphitree/releases/latest).
2. Open it and drag **Graphitree** onto **Applications**. Open Graphitree from Applications, not from the disk image or Downloads: macOS runs a copy opened there from a temporary place, and the `graphitree` command and AI tool settings it sets up would point there.
3. Open Graphitree. The first time, macOS stops it and says Apple couldn't verify it's free of malware. That's because Graphitree is signed with its developer's free Apple account, which can't have Apple notarize it. Click **Done**, not Move to Trash.
4. Open **System Settings › Privacy & Security** and scroll down to **Security**. Next to "“Graphitree.app” was blocked to protect your Mac", click **Open Anyway**, confirm, and enter your login password. The button stays for about an hour after step 3. If it's gone, open Graphitree again.
5. Graphitree walks you through the rest. If graphify isn't installed, it offers **Install graphify**. That puts uv, Astral's tool for Python apps, and graphify in `~/.local/bin` in a minute or two, without changing your shell settings. Then you connect an AI model and choose folders, and it builds your map.

From then on it opens normally.

Instead of steps 3 and 4 you can run this in Terminal. It removes the mark macOS puts on downloads, so macOS skips its check, which is why it's only for a copy from the link above:

```bash
xattr -dr com.apple.quarantine /Applications/Graphitree.app
```

To install graphify yourself instead of in step 5, run these in Terminal, then come back to Graphitree:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

```bash
~/.local/bin/uv tool install graphifyy
```

### Updates

Graphitree checks for a new version once a day. **Graphitree › Check for Updates…** checks now. When there is one, it shows what's new, and **Install Update** downloads it, checks it was signed with Graphitree's release key by the same developer, replaces the app and reopens it. Updates don't need steps 3 and 4 again, and you keep your settings and permissions. A copy built from source, below, gets the same offers once a release is newer.

## Uninstall

Choose **Graphitree › Uninstall Graphitree…**. It lists what it removes and what it keeps, and does nothing until you confirm. If the app won't open, run `graphitree uninstall` in a terminal to see the same list, then `graphitree uninstall --yes` to do it, with Graphitree quit. Without the `graphitree` command, use `/Applications/Graphitree.app/Contents/MacOS/graphitree-cli uninstall`.

It removes:

- Graphitree's lines in your AI tools' instructions files, and its MCP server in chat apps. A copy of each file as it was goes to the Trash.
- The `graphitree` command link, the background job, and the open-at-login job.
- Its AI keys in the Keychain. These can't be put back.
- Its Privacy & Security permissions. macOS doesn't let it reset the `graphitree` command's own Documents access, which the background job asks for, so if you turned that job on, check System Settings › Privacy & Security › Files & Folders afterwards.
- The app, its settings, Application Support folder, the folder it shares with its widgets and the widgets' own sandbox folder, caches and logs, and the backup copies it made of other tools' files. All of these go to the Trash.

It keeps your graph folder with your Playbook, graphify, and any Playbook lines in your repos, which are part of each repo. If Graphitree installed graphify for you, the list says so. `uv tool uninstall graphifyy` removes it. `Shared/Uninstall.swift` has the full list.

A downloaded copy is removed from wherever it is, Downloads included. The disk image you downloaded stays, so delete it yourself.

## What it reads and writes

| File | Owner | Notes |
|---|---|---|
| `graphify-out/graph.json` | graphify | Read only. The rebuild screen asks graphify to rewrite it. |
| `graphify-out/curation.jsonl` | You, through the app | Append-only decisions. Undo adds a `revoke` line. |
| `graphify-out/graph.clean.json` | Derived | `graph.json` with the rules applied. Gitignored. |
| `.graphifyignore` | You | Only changed by "Add to .graphifyignore", after confirming. |
| `~/Library/Application Support/Graphitree/Indexes` | The app | Disposable SQLite indexes. |
| `~/.claude/projects`, `~/Library/Application Support/Claude/local-agent-mode-sessions` | Claude Code, Claude Desktop | Read only, by the Usage page, to count Claude Code's calls on this Mac. |
| `~/.codex/sessions`, `~/.codex/archived_sessions` | Codex | Read only, by the Usage page, for Codex's calls and its plan's limits. Compressed logs (`.jsonl.zst`) are read with Homebrew's `zstd` when it's installed. |
| Keychain item `Claude Code-credentials` | Claude Code | Read only, by the Usage page, to ask Anthropic for the plan's limits. Never refreshed or changed, so it can't sign Claude Code out. |
| `~/Library/Application Support/Graphitree/ClaudeUsage` | The app | The last plan reading, a reading every 5 minutes while the app runs (`usage-history.jsonl`), and a disposable transcript cache. |
| `~/Library/Group Containers/<team>.com.marcuslai.Graphitree/widget-feed.json` | The app | The latest readings, for the desktop widgets, rewritten after each reading. The widgets only read it. |
| `~/Library/LaunchAgents/com.marcuslai.Graphitree.menubar.plist` | The app | Only with Open at login on. Starts Graphitree in the menu bar when you log in. |
| Claude Usage's `usage-history.jsonl`, in its group folder | Claude Usage | Read only when you choose Import History from Claude Usage. macOS asks first. |

To query the cleaned graph: `graphify query "<question>" --graph graphify-out/graph.clean.json`

Ask the graph runs that same `graphify query` on `graph.json`, and on `graph.clean.json` when it's up to date. It sets `GRAPHIFY_QUERY_LOG_DISABLE=1`, so Graphitree's questions don't land in graphify's query log.

## Playbook lab

The Playbook Lab window is a composer for trying UI libraries before you verify them in the Playbook. It starts with an empty canvas:

- Add components (toast, drawer, KPI number, hero, agent step…).
- Pick which library draws each one, set its options, and add extras such as Motion entrance animations or reduced motion.
- Choices that can't run on the canvas, or that go against a Playbook rule, say why. Examples: a library that needs Motion when it's off, a Radix component in a Base UI app, two toast libraries, or a marketing-only effect on an app screen.
- Each block shows its install commands and code, and the canvas copies them all at once.

Library cards show Try It, which opens that library on a fresh canvas. The lab also has a Verdicts table and the older side-by-side notes pages.

The window's toolbar switches between two canvases.

**React · Web** tries web libraries. **SwiftUI · Mac** tries SwiftUI and Swift Charts, and warns when a choice needs a newer macOS than the app supports.

## Usage

The Usage page, under AI Models in the rail, is ported from [Claude Usage](https://github.com/MarcusLai07/claude-usage-widget). A switch in its header picks Claude or Codex.

**Claude**
- **Plan limits**: session, weekly and per-model percentages from `api.anthropic.com/api/oauth/usage`, the endpoint behind Claude Code's `/usage`. They cover the whole account: claude.ai, the desktop app's chat, mobile and Claude Code on every device. The request borrows Claude Code's sign-in from the keychain, read only. Once a reading has worked, Graphitree reads again every 5 minutes while it's open and keeps the history for the left-over-time chart.
- **Claude Code on this Mac**: every call from `~/.claude/projects` and Claude Desktop's local-agent sessions, with tokens, cost at Anthropic API list prices, sessions and the Context tab's auto-compact and prompt-cache advice. Chat in claude.ai or the desktop app leaves no transcript, so it shows only in the limits.

**Codex**
- Everything comes from Codex's own session logs, so there's no sign-in, keychain or network. Each reply logs the plan's 5-hour and weekly limits (`rate_limits` on `token_count`), so the limits are as of Codex's last reply and the left-over-time chart is drawn from the logs themselves. Signed in with an API key, Codex has no plan limits.
- Calls come from `token_usage_record` lines (one per response, newer Codex) or else `token_count` events, counted once even when a forked session repeats them. Cost is at OpenAI API list prices, long-context rates included. The format follows Codex's source (openai/codex, `codex-rs/protocol` and `codex-rs/history`).

**Menu bar, widgets and notifications**

The Usage page's **Menu Bar & Alerts** button sets these up.

- **Menu bar**: Graphitree's mark with Session over Weekly beside it, for Claude or Codex. Its menu shows each plan's limits, resets and pace. While it's on, Graphitree keeps running when you close its window and leaves the Dock until you open it again; quit it from the menu. **Open at login** starts it in the menu bar only.
- **Desktop widgets**: Plan Limits as bars or rings, small, medium or large, for Claude or Codex (edit the widget to pick). The large bars add the week's left-over-time curve. macOS requires widgets to be sandboxed, which keeps Claude Code's sign-in and Codex's logs out of their reach, so Graphitree writes its readings to a folder it shares with them and they draw that. They're as current as Graphitree's last reading; when Graphitree isn't running they say so.
- **Notifications**: when a window passes the share you set (80% to start), when one reaches its limit, when the week is on pace to run out more than six hours early, and when the week is about to reset with much of it unused. Each comes once per cycle, and clicking it opens the Usage page.
- **Moving from Claude Usage**: Import History from Claude Usage adds its readings to Graphitree's, so the left-over-time chart and past weeks carry on.

## Credits

### graphify

Graphitree exists because of [graphify](https://github.com/Graphify-Labs/graphify) by Graphify Labs. graphify does the hard part: it reads your code, docs and configs and turns them into the knowledge graph that Graphitree shows, cleans up and backs up. Every map in Graphitree is graphify's work.

If Graphitree is useful to you, please support graphify:

- Star [Graphify-Labs/graphify](https://github.com/Graphify-Labs/graphify) on GitHub.
- Sponsor its creator through [GitHub Sponsors](https://github.com/sponsors/safishamsi).
- Join its [Discord](https://discord.gg/graphify) or [Discussions](https://github.com/Graphify-Labs/graphify/discussions), or [contribute](https://github.com/Graphify-Labs/graphify/blob/v8/CONTRIBUTING.md).

graphify is a trademark of Graphify Labs. Graphitree is an independent app, not affiliated with or endorsed by them.

### uv, by Astral

[uv](https://github.com/astral-sh/uv) is how Graphitree installs graphify for you, with the Python it runs on, in a minute and without touching the rest of your Mac. Astral builds it, and much of today's Python tooling, in the open. Support their work by starring [astral-sh/uv](https://github.com/astral-sh/uv) and seeing what else they make at [astral.sh](https://astral.sh).

### Everything else

Graphitree also uses GRDB.swift, Sparkle, sigma.js and graphology. Its Playbook lab is built with React and components from shadcn/ui, Magic UI, Animate UI, Vercel AI Elements, blocks.so, Beautiful UI, [ShitUI](https://shitui.in) and Aceternity UI. The AI model logos belong to their companies. Every package the app includes, with its license, is in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and in Graphitree › About Graphitree.

## License

Graphitree's own code is under the [MIT License](LICENSE). The third-party code it includes keeps its own license, listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## For developers

Everything below is for working on Graphitree itself.

### Build from source

You need Xcode (the app) and XcodeGen (`brew install xcodegen`).

```bash
Scripts/install.sh --launch
```

This builds a Release copy, installs it as `/Applications/Graphitree.app` and opens it. Without `--launch` it never opens Graphitree or quits a running one. If you aren't signed in to the project's Apple team, add `--sign-locally`, or put `DEVELOPMENT_TEAM=<your team ID>` in front. A copy signed with `--sign-locally` has no team, so its widgets have no shared folder and show nothing; the menu bar and notifications still work. `Scripts/install.sh --help` lists every option.

To work on it in Xcode:

```bash
xcodegen generate
open Graphitree.xcodeproj
```

### Release

1. Put the new version in `MARKETING_VERSION` in `project.yml`. The build number follows it, and copies of Graphitree update when it's higher than theirs.
2. Write what's new in a Markdown file. It's shown in the update window and on the release page.
3. Commit and push.
4. Run:

```bash
Scripts/release.sh --notes whats-new.md
```

It builds the disk image with `Scripts/package.sh` and signs it with the update key. It writes `appcast.xml`, the update feed, then shows what it will publish and asks. On a yes it creates the GitHub release `v<version>` with the disk image and the feed. The feed's address, in `SUFeedURL`, is the newest release's `appcast.xml`, so every copy sees the release right away. `--dry-run` makes everything in `dist/` and publishes nothing. The repo has to be public, and the GitHub CLI signed in as its owner.

After adding, removing or updating a dependency, run `Scripts/notices.py`. It rewrites `THIRD_PARTY_NOTICES.md` and the copy the app shows in About Graphitree, and `package.sh` won't make a release while they're out of date.

`Scripts/package.sh` alone makes `dist/Graphitree-<version>.dmg` and checks it. The app inside is a clean Release build for Apple silicon and Intel, with Sparkle for updates, signed with the project's Apple team, and with no entitlement that lets other programs debug it. It has to verify inside the disk image. Neither script ever opens Graphitree. The signature names the team's Apple Development certificate, which includes its Apple account's email, and anyone can read it with `codesign -dv`.

**The update key.** Updates are signed with a private key in the owner's login Keychain, under the account `graphitree`. The app holds its public half, `SUPublicEDKey` in `project.yml`. The first time `release.sh` signs, the Keychain asks whether `sign_update` may use the key: choose Always Allow. Keep a backup somewhere safe, such as a password manager. Without the key, copies already out there can't update from inside the app, and people would have to download the next version themselves. To export it:

```bash
build.noindex/package/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys --account graphitree -x graphitree-update-key.txt
```

On another Mac, import it with `-f` in place of `-x`, or pass the file to `release.sh --key-file`. Delete the exported file once it's stored.

### Test

```bash
Scripts/test.sh
```

These compare the app against independent Python calculations:

```bash
Scripts/test.sh --real <graphify-out> > actual.json
python3 -I Scripts/verify_audit.py <graphify-out> actual.json
python3 -I Scripts/verify_clean.py <graphify-out>
```

`verify_clean.py` needs a `graph.clean.json` and `curation.jsonl` in that folder.

### Graph pane

The pane is sigma.js in a web view, bundled with no network access. After editing `Web/src/graph.js`:

```bash
cd Web && npm install && npm run build
```

### Playbook lab

**React · Web** is the React app in `playground/`. It's built into one script and stylesheet in `App/Resources` (`lab.html`, `lab.bundle.js`, `lab.css`) and loaded in a web view with no network access. `lab-manifest.json`, written by the same build from `playground/src/playground/catalog.ts`, lists the libraries the composer can place and the route that opens each (`try/<id>`).

**SwiftUI · Mac** is native, drawn by Graphitree itself. It works the same way, with SwiftUI and Swift Charts as the libraries:

- The main rule is availability. Each way of building a component knows the macOS it needs. The canvas warns when that's newer than the app's deployment target, with the `if #available` to add, and blocks anything this Mac can't draw.
- Extras are the animation style, entrance, Reduce motion, control size, tint and appearance. Each block shows its code.
- The model and rules are in `Shared/SwiftLab.swift`, with each adapter's options and code in `Shared/SwiftLabAdapters/`. Their views are in `App/Views/SwiftLab/`.
- `Scripts/shot.sh lab out.png -labSlots number,chart` renders the canvas, and `Scripts/shot.sh lab <dir>/` renders every slot.

Aceternity UI's components (3D card, aurora background, background beams, card hover effect, hero highlight, lamp, moving border, spotlight and text generate effect) aren't in the repo, since its license doesn't allow sharing their source. The compiled lab in `App/Resources` includes them. To rebuild the lab, copy them from [ui.aceternity.com](https://ui.aceternity.com) into `playground/src/components/ui/` first, under the file names listed in `.gitignore`.

To work on it in a browser, run `npm run dev` in `playground/` (http://localhost:5199). To rebuild what ships in the app:

```bash
cd playground && npm install && npm run build:app
```

### Usage page

The engine is in `Shared/Usage/` (Codex's reader is `CodexSessions.swift`) and the views are in `App/Views/Usage/`. `Tests/UsageChecks.swift` and `Tests/CodexChecks.swift` cover both. `Scripts/shot.sh usage out.png -usageTab requests` renders a tab from the last stored reading, without asking the keychain; add `-usage.provider codex -codexHome <folder>` to render Codex from another folder.

The menu bar is in `App/MenuBar/`: `UsageFeed.swift` keeps both plans read while the app runs and writes the widgets' feed (`Shared/Usage/WidgetFeed.swift`), and `AlertSender.swift` sends what `Shared/Usage/UsageAlerts.swift` finds due. The widget extension is `Widget/`, which compiles only the usage files its drawing needs (see `GraphitreeWidget` in `project.yml`). Its app group is `<team ID>.com.marcuslai.Graphitree`, which macOS lets both use without a provisioning profile; `Scripts/package.sh` fails if a profile ends up in the app. `Tests/WidgetChecks.swift` covers the feed, the notification rules, the login job and the history import. `Scripts/shot.sh widgets <folder>/` draws the menu bar, its menu and every widget size from the last stored reading (`-sample YES` for made-up figures, `-plan codex`, `-showLeft YES`), and `Scripts/shot.sh usagesettings out.png` the settings sheet.

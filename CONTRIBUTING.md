# Contributing to PHOBIA

Thanks for wanting to help. Read this whole file before you open a PR.

## Ground rules

1. **No malicious PRs.** This tool is for authorized testing. Any PR that adds
   capabilities aimed at mass exploitation, ransomware, or targeting random
   victims will be closed and reported.
2. **One feature per PR.** Don't send a mega-PR with 10 modules. Send one, get
   it reviewed, then send the next.
3. **Test on your own lab.** Don't test against systems you don't own.

## How to add a module

1. **Copy the pattern** of an existing module. Look at:
   - `n5_page_cloner` — smallest example
   - `menu_telegram_c2` — menu wrapper
   - `_auto_attack_device` — attack dispatcher
2. **Register it in `menu_surface`** — add a `_3col` row + a case handler.
3. **Follow the naming convention** — module functions are `<menu>_<action>`.
4. **Use the box helpers** (`box_start`, `phb_row`, `menu_footer`) — don't
   raw-`echo` menus.
5. **Log errors to `$PHOBIA_DEBUG_LOG`** — don't `>/dev/null 2>&1` on services.
6. **Syntax check before pushing:** `bash -n phobia.sh`
7. **Test on Kali** with `sudo bash phobia.sh` — confirm nothing else broke.

## Reporting bugs

Open an issue with:
- what you ran
- what you expected
- what actually happened
- `tail -50 logs/debug.log`
- your OS + phobia version

## Known issues

See the `## Known Issues` section in [README.md](README.md). Fixing any of these
is a great first PR.

## Style

- 4-space indent
- lowercase bash except for env vars
- no comments that just restate the code — say *why*, not *what*
- use existing helpers before adding new ones

## Security

If you find a security issue in PHOBIA itself (not a tool it wraps), open a
private issue or DM @zeru.aep. Don't publish exploits for PHOBIA publicly.

## Legal

By submitting a PR you confirm the code is yours (or properly licensed) and
that you understand what PHOBIA does. You are responsible for how your
contribution is used downstream.

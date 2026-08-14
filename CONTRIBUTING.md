# Contributing

Thank you for helping improve IntakeShield. Please open pull requests and issues against the **public GitHub** repository: [Tranquillius/intakeshield](https://github.com/Tranquillius/intakeshield).

This is a community Zammad 7.x **classic** package (classic admin UI). It is not affiliated with Zammad GmbH.

## Development

You need a local Zammad 7.x tree.

```bash
bin/link /path/to/zammad
export DEVELOPMENT_FILE_WATCHER="file_update_checker"
```

Build a distributable package (writes `releases/`, which is gitignored):

```bash
bin/build 0.4.3
```

Do not commit `.zpm` files, `tmp/`, logs, or data from a live Zammad instance.

## Guidelines

- Keep examples generic (`@example.com`, `user@mail.example.com`). Do not add hostnames, e-mail domains, or URLs from a real helpdesk.
- Addon migrations under `db/addon/intake_shield/` must use a **unique** timestamp prefix. Do not rename migrations that already shipped in a release.
- Match existing Ruby / CoffeeScript style. Prefer small, focused changes.
- Update `intake_shield.szpm` (`version`, `change_log`) and [CHANGELOG.md](CHANGELOG.md) when the public version changes.
- Security issues: see [SECURITY.md](SECURITY.md). Do not file them as public issues.

## Releases

1. Bump `version` and `change_log` in `intake_shield.szpm` and [CHANGELOG.md](CHANGELOG.md).
2. Tag `v<version>` on the GitHub `main` branch (for example `v0.4.3`).
3. The [release workflow](.github/workflows/release.yml) builds the `.zpm` and attaches it to a GitHub Release.

You can also run `bin/build <version>` locally and attach the file by hand.

## Publishing this tree to GitHub (maintainers)

GitHub has its **own** history: a clean orphan commit with a public author identity. The private GitLab history (internal author, old instance examples, former `.zpm` blobs) must never be pushed there.

Local remotes:

- `origin` — private GitLab (`main`)
- `github` — public GitHub (`main`, from local branch `public`)

After committing sanitized work on GitLab `main` (copy the tree; never merge `main` into `public`, or GitLab history would leak):

```bash
git checkout public
git restore --source=main --staged --worktree :/
git add -A
git status   # tmp/, releases/, and *.zpm must not be staged

GIT_AUTHOR_NAME='Tranquillius' \
GIT_AUTHOR_EMAIL='7338018+Tranquillius@users.noreply.github.com' \
GIT_COMMITTER_NAME='Tranquillius' \
GIT_COMMITTER_EMAIL='7338018+Tranquillius@users.noreply.github.com' \
git commit -m "Sync public tree"

git push github public:main
```

If `main` deleted files, drop the leftovers on `public` before committing. Then tag and release if the version changed.

Do **not** `git push github main` from GitLab `main`, and do **not** push branch `public` to GitLab.

---

# Mitwirken (Deutsch)

Pull Requests und Issues bitte gegen das **öffentliche GitHub-Repo**. Keine Instanzdaten, keine `.zpm`-Dateien und keine Logs committen. Sicherheitslücken privat über [SECURITY.md](SECURITY.md) melden.

Die GitLab-Historie darf nicht nach GitHub gepusht werden; der öffentliche Stand lebt auf dem lokalen Branch `public` und geht nur an das Remote `github`.

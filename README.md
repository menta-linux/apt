# Menta Linux apt repository

Signed apt repository for the Menta Linux MATE/Wayland packages. It contains **only what is explicitly put into
[`menta-linux/artifacts`](https://github.com/menta-linux/artifacts)**: every non-draft GitHub release there is a
**channel** and becomes an apt suite of the same name (`dists/<channel>`). The `.deb` files attached to the release are
the packages of that channel. Nothing is read from the `pkg-*` build repos directly.

The workflow runs **only on demand** (Actions -> *Publish apt repository* -> *Run workflow*, or `gh workflow run publish.yml -R menta-linux/apt`) and deploys the result to GitHub Pages. There is no schedule and no push trigger, so no automatic CI mails.

## Use it

```
wget -qO- https://menta-linux.github.io/apt/setup.sh | sudo bash                    # channel: unstable
MENTA_CHANNEL=stable sh -c 'wget -qO- https://menta-linux.github.io/apt/setup.sh | sudo -E bash'
sudo apt install mate-desktop marco mate-panel caja
```

`setup.sh` picks the channel from your Debian release (trixie -> `stable`, forky/sid -> `unstable`; override with `MENTA_CHANNEL=...`) and, on trixie, also adds `trixie-backports`.

or by hand:

```
sudo wget -O /usr/share/keyrings/menta.gpg https://menta-linux.github.io/apt/menta.gpg
echo "deb [signed-by=/usr/share/keyrings/menta.gpg] https://menta-linux.github.io/apt unstable main" \
  | sudo tee /etc/apt/sources.list.d/menta.list
sudo apt update
```

Menta versions end in `-1mentaN`, so they sort above Debian's.

## Putting packages into a channel

Package repos (`pkg-*`) keep building to their own rolling releases (`latest` = sid builds, `latest-trixie` = Debian 13 builds). To publish a build, promote it:

```
tools/promote.sh unstable mate-desktop marco mate-panel      # needs `gh auth login` with write access to menta-linux/artifacts
```

This uploads the `.deb`s of each package's rolling release (without `-dbgsym`): `stable` takes the trixie builds (`latest-trixie`), every other channel the sid builds (`latest`) to the `unstable` release of
`menta-linux/artifacts` (creating the release if needed) and removes older versions of the same packages. You can also
attach `.deb` files to a release there by hand. Create a release named `testing` or `stable` to get a new channel;
delete or draft a release to take a channel offline. Then run the *Publish apt repository* workflow to make the change live.

## One-time setup (repo owner)

1. **Pages**: Settings -> Pages -> Source: *GitHub Actions*.
2. **Signing key** (otherwise the repo is published unsigned and clients fall back to `[trusted=yes]`):
   ```
   gpg --quick-gen-key "Menta Linux apt <apt@menta-linux.invalid>" rsa4096 sign never
   gpg --armor --export-secret-keys "Menta Linux apt" > menta-private.asc
   ```
   Add the contents as the repository secret `APT_GPG_PRIVATE_KEY` (a key without passphrase), delete the file, and keep
   a backup of the key somewhere safe.
3. **Private artifacts repo**: if `menta-linux/artifacts` is private, add a secret `MENTA_TOKEN` (fine-grained PAT with
   read access to *Contents* of that repo).
4. Run the *Publish apt repository* workflow once (Actions -> Run workflow).

## Files

- `build-repo.sh <debs-dir> <out-dir>` - `<debs-dir>/<channel>/*.deb` -> pool + dists per channel with `apt-ftparchive`; signs if `GPG_KEY_ID` is set
- `tools/promote.sh <channel> <pkg>...` - copy package builds into a channel release of the artifacts repo
- `setup.sh` - client helper published at the site root

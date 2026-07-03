# Amora Website

Static public website for `planwithamora.com`.

## Local Preview

From the repo root:

```bash
python3 -m http.server 4173 --directory website
```

Open `http://127.0.0.1:4173/`.

## Pages

- `index.html`: public product page.
- `privacy.html`: privacy policy content for `https://planwithamora.com/privacy`.
- `terms.html`: terms content for `https://planwithamora.com/terms`.
- `support.html`: support content for `https://planwithamora.com/support`.

## Deployment Note

The local files use `.html` filenames so they work as a static folder. Configure hosting to route extensionless public URLs to these files:

- `/privacy` -> `/privacy.html`
- `/terms` -> `/terms.html`
- `/support` -> `/support.html`

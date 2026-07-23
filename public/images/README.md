# Images

These are the live photos used by the landing page. To swap any of them, just
replace the file with the same filename — the page picks it up automatically.
If a file is missing, the page shows a labelled placeholder instead.

| Filename        | Where it shows   | Current photo                          | Aspect / size   |
| --------------- | ---------------- | -------------------------------------- | --------------- |
| `hero.jpg`      | Full-screen hero | Raja Ampat karst islands, turquoise bay | wide, 2000×1523 |
| `about.jpg`     | About section    | Palm-fringed beach over clear shallows  | 4:5, 360×450    |
| `feature.jpg`   | Featured strip   | Pink anemone close-up with clownfish    | 4:3, 792×594    |
| `gallery-1.jpg` | Photo gallery    | Clownfish in anemone                    | 1:1, 593×593    |
| `gallery-2.jpg` | Photo gallery    | Clownfish / reef                        | 1:1, 360×360    |
| `gallery-3.jpg` | Photo gallery    | Clownfish / reef                        | 1:1, 360×360    |
| `gallery-4.jpg` | Photo gallery    | Clownfish / reef                        | 1:1, 360×360    |
| `gallery-5.jpg` | Photo gallery    | Clownfish / reef                        | 1:1, 360×360    |
| `gallery-6.jpg` | Photo gallery    | Clownfish portrait                      | 1:1, 360×360    |

Originals live in `/photos` at the project root. These web copies were produced
with macOS `sips` (centre-cropped to the slot's aspect ratio, then JPEG-compressed).

## Replacing a photo

Drop in a new file with the same name, ideally already close to the aspect ratio
above, then commit and push — the site redeploys itself. To re-crop from an
original:

```bash
# centre-crop to HEIGHT WIDTH, then compress
sips -c 593 593 photos/YOUR.jpeg --out public/images/gallery-1.jpg
sips -s format jpeg -s formatOptions 82 public/images/gallery-1.jpg
```

Keep each file under ~400 KB so the page stays fast on GitHub Pages.

## Adding more gallery photos

The gallery is driven by the `galleries` array at the top of
`src/pages/index.astro` — add the next number and a matching `gallery-N.jpg`.

---
name: web
description: >-
  Collect data from websites and write PDF reports, using curl when it
  works and the user's own Chromium (remote debugging port 9222) when the
  user should watch or curl gets blocked. Covers deal hunting with best
  picks and likely scams (like "find good RAM deals on OLX"), and official
  online processes (like "apply for an international driving permit"),
  which are only explored with dummy data and turned into a PDF guide for
  the user to complete themselves.
metadata:
  author: sinanmohd
---

# Web

Use curl when it is faster and gets the data, like plain pages or JSON
endpoints. Switch to the user's running Chromium only when:

- the user should be able to see what is happening, like walking
  through an official form such as a driving permit application
- curl is hard to use, because of bot blocking, captchas, pages that
  render with JavaScript, or data that needs the user's location or login

Chromium is started with `--remote-debugging-port=9222`, so it carries the
user's cookies, location and logins, and sites treat it like a normal
visitor. Do not start a fresh headless browser instead.

## Connect

Check the port first:

    curl -s http://127.0.0.1:9222/json/version

If nothing answers, stop and ask the user whether Chromium is running
with the debug port, started with `--remote-debugging-port=9222`. Do not
launch a browser yourself.

Drive it with Playwright from nixpkgs. It attaches over CDP, so no browser
download is needed:

    nix --extra-experimental-features 'nix-command flakes' shell --impure \
      --expr 'with import (builtins.getFlake "nixpkgs") {}; python3.withPackages (p: [ p.playwright ])' \
      -c python3 -I scrape.py

    from playwright.sync_api import sync_playwright

    with sync_playwright() as p:
        browser = p.chromium.connect_over_cdp("http://127.0.0.1:9222")
        ctx = browser.contexts[0]
        page = ctx.new_page()
        page.goto(url, wait_until="domcontentloaded")
        ...
        page.close()

- Always open your own tab with `ctx.new_page()` and close it when done.
  Never navigate, close or read the user's existing tabs.
- Never call `browser.close()`, it would close the user's browser.
- Keep scripts in the scratchpad directory, not in the repo.
- Go slow: wait a second or two between page loads and do not open
  dozens of tabs in parallel. Stop if the site shows a captcha or a
  login wall, and tell the user.
- Prefer the JSON API the page itself calls over parsing the DOM. Find
  it by logging `page.on("response", ...)` while the page loads or while
  clicking "load more", then call it from inside the page so it carries
  the browser's cookies:

      page.evaluate("async (u) => (await fetch(u)).json()", api_url)

  Do not guess endpoints, only use ones seen in the traffic. Fall back to
  `inner_text()` and `data-*` attributes when there is no API.
- Sites that block curl for pages often still serve images and other
  static files to curl, which is faster for bulk downloads.
- Keep the raw data (JSON) in the scratchpad, so the report can be
  rebuilt or corrected without scraping again.

## PDF reports

When a report is asked for, write it as HTML and print it to PDF with
Chromium itself:

    page.set_content(html, wait_until="load")
    cdp = ctx.new_cdp_session(page)
    pdf = cdp.send("Page.printToPDF", {"printBackground": True})
    open(out, "wb").write(base64.b64decode(pdf["data"]))

Save the PDF in the current working directory unless the user names a
place, give its full path, and never commit it. Make every listing a
clickable link to the original page, and embed a thumbnail of each
listing's first photo as a data URI.

Before handing it over, render the pages and look at them, to catch
broken layout, wrapped columns or wrong numbers:

    nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#poppler-utils \
      -c pdftoppm -r 70 -png report.pdf page

Every number in the text (medians, "cheapest", "only other") must come
from the data, recompute it after any filtering change.

## Deal hunting (examples: "find good RAM deals on OLX", "good deals on a MacBook Pro 16 M1 Pro")

1. Search several phrasings of the query and merge the results by
   listing id, one phrasing misses listings another finds.
2. Read every listing's full description, seller name, account age and
   photos. These are what deal and scam judgements rest on.
3. Drop noise: "buying" ads, accessories and parts, whole machines that
   only mention the part, and the wrong model (14 inch for 16 inch, M1
   Max for M1 Pro). Keep the wrong model ones in a short "not what you
   asked for or unclear" table instead of silently dropping them.
4. Normalise each item into the specs that set its price (for RAM: type,
   DIMM or SO-DIMM, capacity, speed, kit; for laptops: RAM, storage,
   battery health and cycle count), plus price, city, posted date,
   seller, account age and link. Read odd ones by hand, regexes get
   descriptions like "32/512" or "16\1TB" wrong.
5. Know what "good" means: compare against the median of the same
   configuration (price per GB for parts) and against the new or launch
   price.
6. Check the user's location on the site. If it is set to the whole
   country, show the city of each listing instead of ranking by distance.
7. Compare every listing's photos with a perceptual hash (a 16x16 dHash
   with Pillow on the thumbnails, Hamming distance <= 20). It finds the
   same photos on listings from different sellers, and one dealer using
   the same photos for different configurations, so the photos are not
   of the unit for sale.

The PDF has these sections, in order:

- **Summary**: how many results were scraped, how many were relevant,
  the median per configuration, and the new or launch price.
- **Best deals**: the top picks, highlighted, each with a short reason
  why (well under the median for its configuration, better specs for the
  price, battery, seller history, close to the user, recent listing) and
  what to verify before buying.
- **What to check before paying**: for used electronics, meet in person,
  match the serial number, remove Activation Lock or the account in
  front of you, check for company device management on ex-office
  machines, test battery, ports, keys and screen, and never pay an
  advance or "token amount".
- **All deals**: every relevant listing in a table per configuration,
  sorted by price, best picks highlighted.
- **Likely scams**: listings that look like scams, each with the
  reasons, followed by a "be careful with" table for listings that are
  suspicious but not clearly scams. Red flags:
  - a price far below every other listing for the same configuration
  - text pasted from eBay or Amazon ("Time left", "See all item
    conditions", US part numbers)
  - specs that contradict the product or the title (a Touch Bar on a
    model without one, M1 Pro specs under an M1 Max title)
  - the same ad in several cities, or the same unit under several
    accounts at different prices
  - an account created the same day as the listing
  - the price in the description differs from the listing price
  - catalog ads ("all models available", "order basis") with a starting
    price instead of a specific unit
  - a battery at 100% with almost no cycles on a years old device
    (replaced battery or a false claim)
  - photos reused across listings or configurations
  - vague descriptions with no model or specs, advance payment, UPI
    "verification", courier only, moving the chat off the site

Say plainly that the scam section is a judgement from the listing alone,
not proof.

### OLX (olx.in)

- curl to olx.in pages times out, use Chromium. Images on
  `apollo.olx.in` load fine with curl, append `;s=300x600` for a
  thumbnail.
- Search through the site's API from inside an olx.in page, 40 results
  per page, stopping when a page has fewer than 40:

      /api/relevance/v4/search?query=<q>&page=<n>&size=40&location=1000001
        &lang=en-IN&clientId=pwa&platform=web-desktop&relaxedFilters=true

  `location=1000001` is all of India. Each item in `data` has the full
  `description`, `price.value.raw`, `user_name`, `user_created_at`,
  `created_at_first`, `images[].url` and `locations_resolved`, so there
  is no need to open each listing.
- `https://www.olx.in/item/<id>` redirects to the full listing URL.
- The location the user picked is in `localStorage.__recent_locations`.

## Official workflows (example: "apply for an international driving permit")

For anything official, like government services, licences, permits,
visas, taxes, banking, insurance or anything with legal or money
consequences, never complete it for the user. Explore the workflow and
write a PDF guide instead. The user fills it in with their real data,
following the guide.

- Use only obvious dummy data (`Test User`, `01/01/1990`,
  `test@example.com`), and only to reveal what the next steps, fields and
  options are. Never enter the user's real details, even if the browser
  autofills them; clear autofilled fields.
- Stop before any step that submits, pays, uploads documents, books a
  slot, sends an OTP, creates an account or application, or signs
  anything. Note what that step asks for and continue from the docs or
  page text instead.
- Do not use the user's logged in accounts to take actions. Reading
  pages that need a login is fine.

The guide covers: what the process is for and who is eligible, the
documents and fees needed up front, then every step in order with the
page URL, each field and what to put in it, the options and which to
pick, a screenshot where it helps (`page.screenshot()`, embedded as a
data URI), and what happens after submitting (timelines, tracking,
collection).

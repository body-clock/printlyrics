# Changelog

## [1.19.1](https://github.com/body-clock/printlyrics/compare/v1.19.0...v1.19.1) (2026-10-27)


### Bug Fixes

* **search:** keep repeats off LRCLIB and stop on its refusals ([#139](https://github.com/body-clock/printlyrics/issues/139)) ([c2ae4e0](https://github.com/body-clock/printlyrics/commit/c2ae4e0352560bcb9d4f632578c6b612ab6f26f1))
* **search:** report LRCLIB outages without opening faults ([#138](https://github.com/body-clock/printlyrics/issues/138)) ([3bd723e](https://github.com/body-clock/printlyrics/commit/3bd723e947d2d06fa28ea51e427eea0473df8d62))
* **search:** retry overloaded LRCLIB calls within the visitor budget ([#144](https://github.com/body-clock/printlyrics/issues/144)) ([3fb1036](https://github.com/body-clock/printlyrics/commit/3fb10363861d1754b063a9f61d03336543bb77fc))


### Miscellaneous

* **deps:** bump honeybadger from 6.9.3 to 6.10.0 ([#143](https://github.com/body-clock/printlyrics/issues/143)) ([0783c19](https://github.com/body-clock/printlyrics/commit/0783c19ee33b1e2fb87ddabda75d63cd8551a79f))
* **deps:** bump omniauth from 2.1.4 to 2.3.1 ([#142](https://github.com/body-clock/printlyrics/issues/142)) ([b0d5b27](https://github.com/body-clock/printlyrics/commit/b0d5b2761225262a9e7d684ba4470477ec097ef4))
* **deps:** bump sqlite3 from 2.10.0 to 2.10.1 ([#141](https://github.com/body-clock/printlyrics/issues/141)) ([af20306](https://github.com/body-clock/printlyrics/commit/af20306d23c5e10b5a16803a903b782672e97b58))
* **deps:** update net-ssh to 7.3.8 ([#145](https://github.com/body-clock/printlyrics/issues/145)) ([33ffd1d](https://github.com/body-clock/printlyrics/commit/33ffd1df96c68d952f0c9bc3b985f085bd79d840))

## [1.19.0](https://github.com/body-clock/printlyrics/compare/v1.18.1...v1.19.0) (2026-10-24)


### Features

* **design-system:** establish tokens and component contracts ([#135](https://github.com/body-clock/printlyrics/issues/135)) ([45d6ce8](https://github.com/body-clock/printlyrics/commit/45d6ce8aae288616b387c63da4ff7eb6fce41d9c))
* **flash:** make page alerts louder ([#136](https://github.com/body-clock/printlyrics/issues/136)) ([6e8475f](https://github.com/body-clock/printlyrics/commit/6e8475f4578bd77b2b74c00f0929d538e28f4713))
* **songbook:** make each song's layout configurable ([#137](https://github.com/body-clock/printlyrics/issues/137)) ([3eec869](https://github.com/body-clock/printlyrics/commit/3eec86917a7deb0991d8ad41d2a355110f05fb72))


### Bug Fixes

* **header:** keep the site header one size across pages ([#132](https://github.com/body-clock/printlyrics/issues/132)) ([dd70624](https://github.com/body-clock/printlyrics/commit/dd7062425723003335a6e1ba84b74918e9a145bc))
* **search:** rank all source matches and bound each attempt ([#134](https://github.com/body-clock/printlyrics/issues/134)) ([3811851](https://github.com/body-clock/printlyrics/commit/38118515a13787d8bace8c5172062e7bfb08ceac))

## [1.18.1](https://github.com/body-clock/printlyrics/compare/v1.18.0...v1.18.1) (2026-10-22)


### Bug Fixes

* close edge cases around sheets, sets, and reset links ([#127](https://github.com/body-clock/printlyrics/issues/127)) ([#129](https://github.com/body-clock/printlyrics/issues/129)) ([c8a02bf](https://github.com/body-clock/printlyrics/commit/c8a02bf47e5296e4fff2a86b9c4d3a08a0d03023))
* **search:** recover misses the exact match could not reach ([#131](https://github.com/body-clock/printlyrics/issues/131)) ([78081a4](https://github.com/body-clock/printlyrics/commit/78081a4e82bfd1ed64e37324459d09b275d355a3))

## [1.18.0](https://github.com/body-clock/printlyrics/compare/v1.17.1...v1.18.0) (2026-10-22)


### Features

* **accounts:** add optional Google-first accounts and a ten-item library ([#125](https://github.com/body-clock/printlyrics/issues/125)) ([332c716](https://github.com/body-clock/printlyrics/commit/332c716ad599293f32ec3e0a690813505eba3c95))

## [1.17.1](https://github.com/body-clock/printlyrics/compare/v1.17.0...v1.17.1) (2026-10-20)


### Bug Fixes

* **search:** keep LRCLIB overloads from reading as search outages ([#121](https://github.com/body-clock/printlyrics/issues/121)) ([4a403c7](https://github.com/body-clock/printlyrics/commit/4a403c79a20e0196ff8b80f3ca824faf41a0fe5a))

## [1.17.0](https://github.com/body-clock/printlyrics/compare/v1.16.0...v1.17.0) (2026-10-13)


### Features

* **sheet:** put a scannable mark on every printed page ([#112](https://github.com/body-clock/printlyrics/issues/112)) ([c1a8ff7](https://github.com/body-clock/printlyrics/commit/c1a8ff747e65e496257a164cb7e6356b35af60e8))

## [1.16.0](https://github.com/body-clock/printlyrics/compare/v1.15.0...v1.16.0) (2026-10-09)


### Features

* recover a search miss, ask about the print, and rank the demand ([#109](https://github.com/body-clock/printlyrics/issues/109)) ([c161f89](https://github.com/body-clock/printlyrics/commit/c161f89b494af0861b4d53727f52bf0023dc3f8d))

## [1.15.0](https://github.com/body-clock/printlyrics/compare/v1.14.1...v1.15.0) (2026-10-08)


### Features

* **analytics:** name the offer's placement and carry its count ([#104](https://github.com/body-clock/printlyrics/issues/104)) ([d080fd7](https://github.com/body-clock/printlyrics/commit/d080fd70204f528173ab8c22ab92f11eaf20d866))

## [1.14.1](https://github.com/body-clock/printlyrics/compare/v1.14.0...v1.14.1) (2026-10-07)


### Documentation

* write down the git conventions for commits, branches, and promotions ([#100](https://github.com/body-clock/printlyrics/issues/100)) ([727a32a](https://github.com/body-clock/printlyrics/commit/727a32a46c42d65781110fc2854ab6557915d4b2))

## [1.14.0](https://github.com/body-clock/printlyrics/compare/v1.13.0...v1.14.0) (2026-10-07)


### Features

* read the demand list in Umami and gather a visit's sheets ([#97](https://github.com/body-clock/printlyrics/issues/97)) ([d1b1222](https://github.com/body-clock/printlyrics/commit/d1b1222051e80cd93b5078c2fcd4b9aabb245f05))

## [1.13.0](https://github.com/body-clock/printlyrics/compare/v1.12.0...v1.13.0) (2026-10-06)


### Features

* **search:** match the visitor's words and keep a miss on the path to a sheet ([#90](https://github.com/body-clock/printlyrics/issues/90)) ([b409754](https://github.com/body-clock/printlyrics/commit/b409754aff994095ec37ae4659328d1f4a7ac234))

## [1.12.0](https://github.com/body-clock/printlyrics/compare/v1.11.0...v1.12.0) (2026-09-30)


### Features

* **analytics:** measure the entry path and read the demand channel ([#85](https://github.com/body-clock/printlyrics/issues/85)) ([8ce8da7](https://github.com/body-clock/printlyrics/commit/8ce8da740429e6bdfd76928df933e23a93544bac))

## [1.11.0](https://github.com/body-clock/printlyrics/compare/v1.10.0...v1.11.0) (2026-09-30)


### Features

* **analytics:** activate the Umami site and read its credentials from Proton Pass ([#82](https://github.com/body-clock/printlyrics/issues/82)) ([356ac4f](https://github.com/body-clock/printlyrics/commit/356ac4f36596ba48239139353f61622612350a7a))

## [1.10.0](https://github.com/body-clock/printlyrics/compare/v1.9.0...v1.10.0) (2026-09-30)


### Features

* **analytics:** self-host Umami and retire the Google Analytics dual run ([#78](https://github.com/body-clock/printlyrics/issues/78)) ([c38bc2f](https://github.com/body-clock/printlyrics/commit/c38bc2fc859777c061139b883039183963559dd2))

## [1.9.0](https://github.com/body-clock/printlyrics/compare/v1.8.0...v1.9.0) (2026-09-28)


### Features

* ship visitor feedback behind a Cloudflare Turnstile gate ([#74](https://github.com/body-clock/printlyrics/issues/74)) ([077db3a](https://github.com/body-clock/printlyrics/commit/077db3afedc05a163dcd01ba1962a1ef4b319b0e))

## [1.8.0](https://github.com/body-clock/printlyrics/compare/v1.7.1...v1.8.0) (2026-09-24)


### Features

* ship the songbook printing guide and query-shaped search copy ([#71](https://github.com/body-clock/printlyrics/issues/71)) ([17dfec2](https://github.com/body-clock/printlyrics/commit/17dfec24eaa1e128a4e9e30b27fc6d0fceb3c453))

## [1.7.1](https://github.com/body-clock/printlyrics/compare/v1.7.0...v1.7.1) (2026-09-24)


### Bug Fixes

* **analytics:** send the GA4 measurement ID as a JavaScript literal ([#66](https://github.com/body-clock/printlyrics/issues/66)) ([f71b1bb](https://github.com/body-clock/printlyrics/commit/f71b1bbc672a2b8a5bdbb2db1b30ca1b55c80027))

## [1.7.0](https://github.com/body-clock/printlyrics/compare/v1.6.0...v1.7.0) (2026-09-21)


### Features

* ship songbooks and a Google Analytics dual run ([#62](https://github.com/body-clock/printlyrics/issues/62)) ([d639dca](https://github.com/body-clock/printlyrics/commit/d639dca263020abf5fa4c5a856dcd601c225ecb6))

## [1.6.0](https://github.com/body-clock/printlyrics/compare/v1.5.0...v1.6.0) (2026-09-15)


### Features

* remove the public song catalog and ship print-intent SEO improvements ([#55](https://github.com/body-clock/printlyrics/issues/55)) ([9518e2d](https://github.com/body-clock/printlyrics/commit/9518e2df7bc9fd5fce563b8d536fb610fe3beaba))

## [1.5.0](https://github.com/body-clock/printlyrics/compare/v1.4.5...v1.5.0) (2026-09-15)


### Features

* add multi-song analytics, a real CSP, and catalog fixes ([#50](https://github.com/body-clock/printlyrics/issues/50)) ([49e3563](https://github.com/body-clock/printlyrics/commit/49e35635e144750b93b1160767b1d3974fdca5a1))

## [1.4.5](https://github.com/body-clock/printlyrics/compare/v1.4.4...v1.4.5) (2026-09-03)


### Bug Fixes

* paginate print preview to match printed output ([#40](https://github.com/body-clock/printlyrics/issues/40)) ([7928133](https://github.com/body-clock/printlyrics/commit/7928133d1178e6ce620ec34159bc03085edd8a3f))

## [1.4.4](https://github.com/body-clock/printlyrics/compare/v1.4.3...v1.4.4) (2026-09-03)


### Bug Fixes

* release mobile print preview parity ([#32](https://github.com/body-clock/printlyrics/issues/32)) ([832e59f](https://github.com/body-clock/printlyrics/commit/832e59fc6cca8e9dd3398e09e4ecf2f7f93c4db9))

## [1.4.3](https://github.com/body-clock/printlyrics/compare/v1.4.2...v1.4.3) (2026-09-03)


### Miscellaneous

* **deps-dev:** bump selenium-webdriver from 4.46.0 to 4.48.0 ([#37](https://github.com/body-clock/printlyrics/issues/37)) ([aeb35f2](https://github.com/body-clock/printlyrics/commit/aeb35f27d7dc51a69d5bff112d4ff45cdc05ffc0))
* **deps:** bump thruster from 0.1.23 to 0.1.26 ([#36](https://github.com/body-clock/printlyrics/issues/36)) ([692a7a5](https://github.com/body-clock/printlyrics/commit/692a7a58ff598cf2b8965e495d0ec96b93b8c48c))

## [1.4.2](https://github.com/body-clock/printlyrics/compare/v1.4.1...v1.4.2) (2026-08-13)


### Bug Fixes

* release search and print improvements ([#29](https://github.com/body-clock/printlyrics/issues/29)) ([2725aa1](https://github.com/body-clock/printlyrics/commit/2725aa14338dcc80173497b9d6552b7058c6e83f))

## [1.4.1](https://github.com/body-clock/printlyrics/compare/v1.4.0...v1.4.1) (2026-08-06)


### Bug Fixes

* **deps:** update Rails to 8.1.3.1 ([c426b08](https://github.com/body-clock/printlyrics/commit/c426b081e44ae771eb60c6a597e33eec0b565a03))
* preserve two columns in mobile PDFs ([c426b08](https://github.com/body-clock/printlyrics/commit/c426b081e44ae771eb60c6a597e33eec0b565a03))

## [1.4.0](https://github.com/body-clock/printlyrics/compare/v1.3.0...v1.4.0) (2026-07-28)


### Features

* add i18n support, campaign tracking, and print use-case feedback ([#20](https://github.com/body-clock/printlyrics/issues/20)) ([c9e6764](https://github.com/body-clock/printlyrics/commit/c9e6764d2fb3d5afe2b7108957baf625efb2593f))

## [1.3.0](https://github.com/body-clock/printlyrics/compare/v1.2.2...v1.3.0) (2026-07-28)


### Features

* publish organic search and privacy-safe song catalog ([#18](https://github.com/body-clock/printlyrics/issues/18)) ([e4a07d6](https://github.com/body-clock/printlyrics/commit/e4a07d62cfc54dccdff423d4d2107ca2263abd0c))

## [1.2.2](https://github.com/body-clock/printlyrics/compare/v1.2.1...v1.2.2) (2026-07-28)


### Bug Fixes

* add Plausible analytics tracking ([#10](https://github.com/body-clock/printlyrics/issues/10)) ([ca6e371](https://github.com/body-clock/printlyrics/commit/ca6e371dbec25dda564ec99da4da47e84abb8a33))

## [1.2.1](https://github.com/body-clock/printlyrics/compare/v1.2.0...v1.2.1) (2026-07-27)


### Bug Fixes

* bypass cached placeholder favicon ([#8](https://github.com/body-clock/printlyrics/issues/8)) ([031efa8](https://github.com/body-clock/printlyrics/commit/031efa85a5c5edacec9c703c87fffd43f84b9929))

## [1.2.0](https://github.com/body-clock/printlyrics/compare/v1.1.0...v1.2.0) (2026-07-27)


### Features

* improve search experience and discoverability ([#6](https://github.com/body-clock/printlyrics/issues/6)) ([77ed018](https://github.com/body-clock/printlyrics/commit/77ed0185ccec4977492683ece24496403ddf62ed))

## [1.1.0](https://github.com/body-clock/printlyrics/compare/v1.0.0...v1.1.0) (2026-07-27)


### Features

* replace URL scraping with song search ([#4](https://github.com/body-clock/printlyrics/issues/4)) ([960b1c5](https://github.com/body-clock/printlyrics/commit/960b1c597ad9d20f34ab97e05083e1cff9524857))

## 1.0.0 (2026-07-27)


### Features

* launch PrintLyrics ([d08f661](https://github.com/body-clock/printlyrics/commit/d08f6613f78b46a75cfda30ea5872fa315510ad4))

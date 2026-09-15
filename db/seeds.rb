# The public song catalog was removed. Its metadata-only pages earned search
# impressions but no clicks, because the queries they targeted want to read
# lyrics rather than print them, and PrintLyrics deliberately serves no lyrics
# on public pages. Songs are now created on demand when someone generates a
# sourced lyric sheet, so there is nothing to seed. This file stays so that
# `db:seed` and `db:seed:replant` remain valid commands.

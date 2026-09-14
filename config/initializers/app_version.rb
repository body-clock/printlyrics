# Read once at boot so each rendered page does not read the file again.
# `bin/rails restart` after changing version.txt.
Rails.application.config.x.app_version = Rails.root.join("version.txt").read.strip.freeze

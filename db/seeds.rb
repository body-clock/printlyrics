# A launch catalog based on songs appearing near the top of the Genius global
# chart on July 16, 2026. Each entry maps to a printable LRCLIB record. Seeds
# contain metadata only and never store lyrics.
popular_songs = [
  { source_id: 17825857, title: "Total Eclipse of the Heart", artist: "Bonnie Tyler", album: "Total Eclipse: the Bonnie Tyler Anthology", duration_seconds: 271 },
  { source_id: 25416792, title: "Three Lions", artist: "Baddiel, Skinner & The Lightning Seeds", album: "Three Lions", duration_seconds: 225 },
  { source_id: 31591022, title: "Creep", artist: "Radiohead", album: "Radiohead - Creep", duration_seconds: 234 },
  { source_id: 27428437, title: "Lose Yourself", artist: "Eminem", album: "Lose Yourself", duration_seconds: 253 },
  { source_id: 36937513, title: "FREAKED OUT", artist: "Fat Papi & prodshushy", album: "Fat Papi", duration_seconds: 158 },
  { source_id: 36779822, title: "Dai Dai", artist: "Shakira & Burna Boy", album: "Dai Dai", duration_seconds: 240 },
  { source_id: 15501988, title: "Mr. Brightside", artist: "The Killers", album: "Mr. Brightside", duration_seconds: 225 },
  { source_id: 36103662, title: "Wonderwall", artist: "Oasis", album: "Oasis - Wonderwall", duration_seconds: 279 },
  { source_id: 35373826, title: "the cure", artist: "Olivia Rodrigo", album: "Olivia Rodrigo", duration_seconds: 298 },
  { source_id: 17008243, title: "Baby (feat. Ludacris)", artist: "Justin Bieber", album: "Justin Bieber", duration_seconds: 214 },
  { source_id: 33738192, title: "Janice STFU", artist: "Drake", album: "Janice STFU", duration_seconds: 236 },
  { source_id: 35948732, title: "stupid song", artist: "Olivia Rodrigo", album: "Olivia Rodrigo Videos", duration_seconds: 210 },
  { source_id: 36954305, title: "honeybee", artist: "Olivia Rodrigo", album: "Olivia Rodrigo", duration_seconds: 223 },
  { source_id: 33389527, title: "Chicago", artist: "Michael Jackson", album: "Michael Jackson - Chicago", duration_seconds: 248 },
  { source_id: 37072983, title: "misery.", artist: "pupsies", album: "pupsies", duration_seconds: 166 },
  { source_id: 3204955, title: "Ramenez la coupe à la maison", artist: "Vegedream", album: "Vegedream - Ramenez la coupe à la maison", duration_seconds: 236 },
  { source_id: 28453866, title: "Bring Me to Life", artist: "Evanescence", album: "Evanescence - Bring Me To Life", duration_seconds: 238 },
  { source_id: 35912356, title: "hate that i made you love me", artist: "Ariana Grande", album: "hate that i made you love me", duration_seconds: 170 },
  { source_id: 3205061, title: "Viva La Vida", artist: "Coldplay", album: "Coldplay - Viva La Vida", duration_seconds: 242 },
  { source_id: 21916123, title: "Without Me", artist: "Eminem", album: "Without Me", duration_seconds: 290 }
]

popular_songs.each do |metadata|
  song = Song.find_or_initialize_by(source_id: metadata.fetch(:source_id))
  song.assign_attributes(metadata) if song.new_record?
  song.indexable_at ||= Time.current
  song.last_verified_at ||= Time.current
  song.save!
end

class LyricPageCreation
  attr_reader :lyric

  def initialize(attributes: {}, catalog_token: nil)
    @attributes = attributes.to_h.symbolize_keys.slice(:title, :artist, :lyrics)
    @catalog_token = catalog_token
  end

  def save
    metadata = SongCatalogToken.verify(@catalog_token)
    return save_manual unless metadata

    save_sourced(metadata)
  end

  private

  def save_manual
    @lyric = Lyric.new(@attributes)
    @lyric.save
  end

  def save_sourced(metadata)
    Lyric.transaction do
      song = find_or_create_song(metadata)

      song.with_lock do
        @lyric = song.lyrics.build(@attributes)
        @lyric.source_url = "https://lrclib.net/api/get/#{song.source_id}"
        @lyric.save!
        song.promote!(metadata)
      end
    end

    true
  rescue ActiveRecord::RecordInvalid
    @lyric ||= Lyric.new(@attributes)
    false
  end

  def catalog_attributes(metadata)
    metadata.slice(:title, :artist, :album, :duration_seconds)
  end

  def find_or_create_song(metadata)
    Song.find_or_create_by!(source_id: metadata.fetch(:source_id)) do |candidate|
      candidate.assign_attributes(catalog_attributes(metadata))
    end
  rescue ActiveRecord::RecordNotUnique
    Song.find_by!(source_id: metadata.fetch(:source_id))
  end
end

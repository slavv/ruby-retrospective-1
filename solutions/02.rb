class Song
  attr_reader :name, :artist, :genre, :subgenre, :tags
  
  def initialize(name, artist, genre, subgenre, tags)
    @name, @artist, @tags = name, artist, tags
    @genre, @subgenre = genre, subgenre
  end
  
  def match? type, value  
    case type
      when :name then value == @name
      when :artist then value == @artist 
      when :filter then value[self]
      when :tags then match_tags?(value)
     end
  end
  
  def match_tags?(criteria_tags)
    Array(criteria_tags).all? do |tag|
      tag.end_with?("!") ^ @tags.include?(tag.chomp "!")
    end
  end 
end

class Collection
  def initialize(songs_as_string, artist_tags)
    @songs = songs_as_string.lines.map { |song| song.strip.split(/\.\s*/)}
    @songs = @songs.map do |name, artist, genre_subgenre, tags_as_string|
      genre, subgenre = genre_subgenre.split(/,\s*/)
      tags = artist_tags.fetch(artist, [])
      tags += tags_as_string.split(/,\s*/) if tags_as_string
      tags += [genre, subgenre].compact.map(&:downcase)
	  Song.new(name, artist, genre, subgenre, tags)
    end
  end
  
  def find(criteria)
    @songs.select do |song|
      criteria.all? {| key, value | song.match?(key, value)}
    end 
  end
end

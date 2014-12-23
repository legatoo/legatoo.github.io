# This goes in _plugins/excerpt.rb
module Jekyll
  class Post
    alias_method :original_to_liquid, :to_liquid
    def to_liquid(attrs = nil)
      Utils.deep_merge_hashes( original_to_liquid(attrs), ({
              'excerpt' => content.match('<!--more-->') ? content.split('<!--more-->').first : nil
            }))
    end
  end
end

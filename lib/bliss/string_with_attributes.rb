module Bliss
  class StringWithAttributes < String
    def attributes
      @attributes ||= {}
    end
    alias_method :attrs, :attributes

    def inspect
      if @attributes.nil? || @attributes.empty?
        super
      else
        "#{super} (@attributes=#{attributes.inspect})"
      end
    end
  end
end

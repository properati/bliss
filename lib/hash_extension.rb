class Hash
  def value_at_chain(chain)
    current = self
		return nil if chain.size == 0
    chain.each_with_index do |key, i|
			if current.is_a? Array
				current = current.last
			end
      if current.is_a? Hash and current.has_key? key
        if current.is_a? Array
          current = current.last
        end
        current = current[key]
      else
        current = nil
        break
      end
    end
    return current
  end

  def pair_at_chain(chain)
    chain = chain.dup
    chain.pop
    return self.value_at_chain(chain)
  end

  def recurse(include_root=false, depth=[], &block)
    self.each_pair { |k,v|
      if v.is_a? Hash
        if include_root
          block.call(depth + [k], v)
        end
        depth.push k
        v.recurse(include_root, depth, &block)
      else
        block.call(depth + [k], v)
        #return "#{depth + [k]}: #{v.inspect}"
      end
    }
    depth.pop
  end
end

class StringWithAttrs
  include Comparable

  APOS = "'".freeze
  APOS_RE = /'/.freeze
  DOUBLE_APOS = "''".freeze

  def initialize(str)
    @data = str
    @attrs = {}
  end

  def attrs
    @attrs
  end

  def <=>(other)
    @data <=> other
  end

  def inspect
    if @attrs.empty?
      "#{@data.inspect} (@attrs=#{attrs.inspect})"
    else
      @data.inspect
    end
  end

  def to_s
    @data.to_s
  end

  def sql_literal(ds)
    "" << APOS << gsub(APOS_RE, DOUBLE_APOS) << APOS
  end

  def method_missing(name, *args, &block)
    if @data.respond_to?(name)
      @data.send(name, *args, &block)
    else
      super
    end
  end

  def respond_to?(name, include_private=false)
    @data.respond_to?(name, include_private) || super
  end
end

require "em-http/decoders"

module EventMachine::HttpDecoders
  class GZip < Base
    # @see https://github.com/igrigorik/em-http-request/issues/207
    def decompress_with_workaround(compressed)
      puts "patched decompress"
      @buf ||= LazyStringIO.new
      @buf << compressed

      decomp = nil

      # Zlib::GzipReader loads input in 2048 byte chunks
      while @buf.size > 2048
        @gzip ||= Zlib::GzipReader.new @buf
        if decomp
          decomp << @gzip.readline
        else
          decomp = @gzip.readline
        end
      end

      decomp
    end
    alias_method :decompress_without_workaround, :decompress
    alias_method :decompress, :decompress_with_workaround
  end
end

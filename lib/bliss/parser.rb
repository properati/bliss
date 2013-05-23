require "zip/zip"
require "open-uri"

module Bliss
  class Parser
    attr_reader :header
    attr_reader :push_parser
    attr_reader :parser_machine
    attr_accessor :unhandled_bytes
    attr_accessor :autodetect_compression

    def initialize(path, filepath=nil, authorization=nil)
      @path = path

      if filepath
        @file = File.new(filepath, 'w')
        @file.autoclose = false
      end

      if authorization
        @user, @pass = authorization
      end

      @header = nil
      @root = nil
      @nodes = nil
      @formats = []

      @zstream = nil

      @machine_builder = Bliss::ParserMachineBuilder.new(self)
      self
    end

    def on_error(&block)
      @machine_builder.on_error(&block)
    end

    def on_tag_open(element='.', &block)
      @machine_builder.on_tag_open(element, block)
    end

    def on_tag_close(element='.', &block)
      @machine_builder.on_tag_close(element, block)
    end

    def add_format(format)
      @formats.push(format)
    end

    def formats
      @formats
    end

    #def load_constraints_on_parser_machine
    #  @parser_machine.constraints(@formats.collect(&:constraints).flatten)
    #end

    def current_depth
      @parser_machine.current_depth
    end

    def current_node
      @parser_machine.current_node
    end

    def formats_details
      #@formats.each do |format|
      #  puts format.details.inspect
      #end
      @formats.collect(&:details)
    end

    def formats_index
      @formats.collect(&:index)
    end

    def on_max_unhandled_bytes(bytes, &block)
      @max_unhandled_bytes = bytes
      @on_max_unhandled_bytes = block
    end

    def initialize_push_parser
      @parser_machine, @push_parser = @machine_builder.build_parser_machine
      reset_unhandled_bytes
    end

    def on_timeout(seconds, &block)
      @timeout = seconds
      @on_timeout = block
    end

    def on_finished(&block)
      @on_finished = block
    end

    def wait_tag_close(element)
      @wait_tag_close = "</#{element}>"
    end

    def reset_unhandled_bytes
      return false if not check_unhandled_bytes?
      @unhandled_bytes = 0
    end

    def check_unhandled_bytes
      if @unhandled_bytes > @max_unhandled_bytes
        if @on_max_unhandled_bytes
          @on_max_unhandled_bytes.call
          @on_max_unhandled_bytes = nil
        end
      end
    end

    def exceeded?
      return false if not check_unhandled_bytes?
      if @unhandled_bytes > @max_unhandled_bytes
        return true
      end
    end

    def check_unhandled_bytes?
      @max_unhandled_bytes ? true : false
    end

    def set_header(header)
      return if header.empty?
      @header ||= header
    end

    def header
      @header
    end

    def zstream
      @zstream
    end

    def set_zstream=(zstream)
      @zstream = zstream
    end

    def root
      @root
    end

    def close
      @parser_machine.close
    end

    def trigger_error_callback(error_type, details={})
      if @machine_builder.error_callback_defined?
        @machine_builder.call_on_error(error_type, details)
      end
    end

    def require_auth?
      !@user.nil? && !@pass.nil?
    end

    def parse_zip
      reset_unhandled_bytes if check_unhandled_bytes?
      self.initialize_push_parser

      compressed_data = open(@path).read
      temp_file = File.join("/tmp", "bliss_tmp_#{Time.now.to_i}.zip")
      fd = open(temp_file, "w")
      fd.write(compressed_data)
      fd.close

      Zip::ZipInputStream.open(temp_file) do |stream|
        entry = stream.get_next_entry
        while !stream.eof?
          self.parse_chunk(stream.sysread(100000).chomp)
        end
      end
      File.delete(temp_file)
      file_close
    end

    def parse
      reset_unhandled_bytes if check_unhandled_bytes?
      #load_constraints_on_parser_machine
      self.initialize_push_parser

      EM.run do
        http = nil
        options = {}

        require_auth? && options = {:head => {'authorization' => [@user, @pass]}}

        if @timeout
          http = EM::HttpRequest.new(@path, :connect_timeout => @timeout, :inactivity_timeout => @timeout).get options
        else
          http = EM::HttpRequest.new(@path).get options
        end

        parser = self
        @autodetect_compression = true if @autodetect_compression.nil?
        compression = :none
        if @autodetect_compression
          http.headers do
            if (/^attachment.+filename.+\.gz/i === http.response_header['CONTENT_DISPOSITION']) or ["application/octet-stream", "application/x-gzip", "application/gzip"].include? http.response_header['CONTENT_TYPE'] or http.response_header.compressed?
              parser.set_zstream = Zlib::Inflate.new(Zlib::MAX_WBITS+16)
              compression = :gzip
            end
          end
        end

        decoder_class = nil
        decoder = nil

        http.stream do |chunk|
          if compression != :none and decoder.nil?
            # valid decoders: "gzip", "deflate"
            decoder_class = EM::HttpDecoders.decoder_for_encoding(compression.to_s)
            decoder = decoder_class.new do |chunk|
              parser.parse_chunk(chunk)
            end
          end

          if chunk
            if decoder
              decoder << chunk
            else
              parser.parse_chunk(chunk)
            end
          end
        end

        http.errback do
          #puts 'errback'
          if @timeout
            @on_timeout.call
          end
          parser.secure_close
        end

        http.callback do |http|
          if compression != :none
            decoder.finalize!
          end
          if @on_finished
            @on_finished.call(http)
          end
          parser.secure_close
        end
      end

      file_close
    end

    def handle_wait_tag_close(chunk)
      begin
        last_index = chunk.index(@wait_tag_close)
        if last_index
          last_index += 4
          @file << chunk[0..last_index]
          @file << "</#{self.root}>" # TODO set this by using actual depth, so all tags get closed
          secure_close
        else
          @file << chunk
        end
      rescue
        secure_close
      end
    end

    def file_close
      if @file
        @file.close
      end
    end

    def secure_close
      begin
        if @zstream
          @zstream.close
        end
      rescue
      ensure
        EM.stop
        #puts "Closed secure."
      end
    end

    def parse_chunk(chunk)
      chunk.force_encoding('UTF-8')

      chunk.lines.each do |line|

        if self.check_unhandled_bytes?
          self.unhandled_bytes += line.length
          self.check_unhandled_bytes
        end

        if not self.parser_machine.is_closed?
          begin
            if not self.header
              self.set_header(line)
            end
            self.push_parser << line
          rescue Nokogiri::XML::SyntaxError => e
            puts e
            if e.message.include?("encoding")
              current_depth = self.current_depth.dup
              current_node = self.current_node.dup

              self.initialize_push_parser
              self.push_parser << self.header
              #puts self.header
              current_depth[0..-2].each { |tag|
                tag = "<#{tag}>"
                #puts tag
                self.push_parser << tag
              }
              self.parser_machine.ignore_next_close(current_depth[0..-2].join("/"))
              self.trigger_error_callback("encoding", {
                :partial_node => current_node,
                :line => line
              })
              #raise Bliss::EncodingError, "Wrong encoding given"
            end
            next
          end
          if @file
            @file << line
          end
        else
          if self.exceeded?
            #puts 'exceeded'
            self.secure_close
          else
            if @file
              if @wait_tag_close
                #puts 'handle wait'
                self.handle_wait_tag_close(chunk) #if @wait_tag_close
              else
                #puts 'secure close'
                self.secure_close
              end
            end
          end
        end

      end
    end
  end
end

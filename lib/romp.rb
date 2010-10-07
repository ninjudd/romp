require 'socket'
require 'pp'

class Romp
  class Frame
    attr_reader :type, :headers, :body
    def initialize(type, headers, body)
      @type    = type.freeze
      @headers = headers.freeze
      @body    = body.freeze
    end
  end

  def initialize(*args)
    if args.size == 1
      @io = args.first
    else
      @io = TCPSocket.new(*args)
    end
  end

  def close
    @io.close
  end

  [:subscribe, :unsubscribe, :begin, :commit, :abort, :ack].each do |command|
    define_method(command) do |*args|
      headers = args.first || {}
      send_frame(command, headers)
    end
  end

  def send(body, headers = {})
    send_frame(:send, headers, body)
  end

  def with_connection(headers = {})
    send_frame(:connect, headers)

    begin
      yield receive(:connected)
    ensure
      send_frame(:disconnect)
    end
  end

  def receive(expected_type = nil)
    type    = @io.gets.chomp.downcase.to_sym
    headers = {}
    while line = @io.gets
      key, val = line.chomp.split(':')
      break unless val
      headers[key.to_sym] = val
    end

    if len = headers[:content_length]
      body = @io.read(len)
      assert_read("\0")
    else
      body = ''
      while c = @io.read(1)
        break if c == "\0"
        body << c
      end
    end
    assert_read("\n")
    raise "expected #{expected_type} frame, got #{type}\n#{headers[:message]}\n#{body}" if expected_type and type != expected_type
    Frame.new(type, headers, body)
  end

private

  def assert_read(expected)
    string = @io.read(expected.size)
    raise "expected #{expected.inspect} got #{string.inspect}" unless string == expected
  end

  def send_frame(command, headers = {}, body = '')
    @io.puts(command.to_s.upcase)
    headers.each do |key, val|
      @io.puts("#{key}:#{val}")
    end
    @io.puts("content-length:#{body.size}")
    @io.puts
    @io.write(body)
    @io.puts("\0")
  end
end

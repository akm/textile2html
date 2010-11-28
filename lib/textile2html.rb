require 'fileutils'
require 'erb'
require 'rubygems'
require 'RedCloth'

class Textile2Html

  DEFAULT_OPTIONS = {
    :layout => File.expand_path("./textile2html_layout.html.erb", File.dirname(__FILE__)),
    :src_dir => File.expand_path("."),
    :dest_dir => File.expand_path("."),
    :noop => false,
    :verbose => false,
  }

  attr_reader :options
  def initialize
    @options = DEFAULT_OPTIONS.dup
  end

  def binding_for_yield
    binding
  end

  def pickup_headers(body)
    links = []
    result = body.gsub(/(<h[1-6]>)(.*?)<\/h[1-6]>/) do |*args|
      # puts "args: #{args.inspect}"
      tag, desc = $1, $2
      depth = tag.gsub(/\D/, '').to_i
      links << [depth, desc]
      "<h#{depth}><a name=\"#{desc}\">#{desc}</a></h#{depth}>"
    end
    return result, links
  end

  def build_page_outlines(links)
    src = links.map{|(depth, desc)| "#" * depth << ' "' << desc << '":#' << desc }.join("\n")
    RedCloth.new(src).to_html
  end

  def execute
    src_dir = File.expand_path(options[:src_dir])
    src_files = Dir["#{src_dir}/**/*.textile"]
    src_files.each do |src_file|
      src = File.read(src_file)
      html_body = RedCloth.new(src).to_html

      html_body, links = pickup_headers(html_body)

      b = binding_for_yield do|*args|
        arg = args.first
        case arg
        when nil then html_body
        when :page_outline then build_page_outlines(links)
        else
          nil
        end
      end

      erb = ERB.new(File.read(options[:layout]))
      html = erb.result(b)
      rel_path = src_file.sub("#{Regexp.escape(src_dir)}/", '')
      dest_rel_path = rel_path.sub(/\.textile$/, '.html')
      dest_path = File.expand_path(dest_rel_path, options[:dest_dir])
      dest_dir = File.dirname(dest_path)
      FileUtils.mkdir_p(dest_dir)
      File.open(dest_path, "w"){|f| f.puts(html)}
    end
  end

end
